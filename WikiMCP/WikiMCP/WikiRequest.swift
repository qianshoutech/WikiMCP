//
//  WikiRequest.swift
//  WikiMCP
//
//  Created by phoenix on 2025/12/15.
//

import Foundation
import Alamofire

// MARK: - Search Response Models

struct WikiSearchResponse: Codable {
    let results: [WikiSearchResult]
    let start: Int
    let limit: Int
    let totalSize: Int
    let cqlQuery: String?
    let searchDuration: Int?
    
    enum CodingKeys: String, CodingKey {
        case results, start, limit, totalSize, cqlQuery, searchDuration
    }
}

struct WikiSearchResult: Codable {
    let content: WikiContent?
    let title: String?
    let excerpt: String?
    let url: String?
    let resultGlobalContainer: WikiContainer?
    let entityType: String?
    let iconCssClass: String?
    let lastModified: String?
    let friendlyLastModified: String?
}

struct WikiContent: Codable {
    let id: String?
    let type: String?
    let status: String?
    let title: String?
    let space: WikiSpace?
    
    enum CodingKeys: String, CodingKey {
        case id, type, status, title, space
    }
}

struct WikiSpace: Codable {
    let id: Int?
    let key: String?
    let name: String?
    let type: String?
    let icon: WikiIcon?
    
    enum CodingKeys: String, CodingKey {
        case id, key, name, type, icon
    }
}

struct WikiIcon: Codable {
    let path: String?
    let width: Int?
    let height: Int?
    let isDefault: Bool?
}

struct WikiContainer: Codable {
    let title: String?
    let displayUrl: String?
}



// MARK: - Wiki API Client

final class WikiAPIClient {
    
    static let shared = WikiAPIClient()
    
    private let baseURL = "https://wiki.p1.cn"
    
    private var defaultHeaders: HTTPHeaders {
        [
            "Cookie": "seraph.confluence=78479924%3A9a9e8667733c07df5acb7d56b81df8f3d3a1ab4b; _webtracing_device_id=t_13501817-932f6e30-8296ccabc848aa53; actoken=5b3d1323a2c3bbcdcef7afed1431148f3057; _webtracing_session_id=s_13502457-abdb1571-014cf1da90f9f741; mywork.tab.tasks=false; qs_sso_auth_at=01WsSwzOnxoBQNOhyqj8Kpa+I9OQxcwUQjbffQ9Do6fVMtQpiXB43NUmYZfWXwEIoQo2x+4u1FF3QR7jlvE4r7pfd+JeglJck3kZ1q8XOv2DUb4WY8reWKY/+0QHMjJ3nASbNNG+YFZsdjlLlw1ykxECD6k0sWoxEYzS8NEvheNVx6xFTkCattEJAD/jPiHz0qBuULZXHnwVvLRKpqbRZtW5aPFahOA2ToCGl0ZRVS3wWfeQI=; JSESSIONID=9BC4CAD80339533E35363E5BC203587A"
        ]
    }
    
    private init() {}
    
    // MARK: - Search API
    
    /// 搜索 Wiki 内容
    /// - Parameters:
    ///   - query: 搜索关键词
    ///   - start: 起始位置，默认 0
    ///   - limit: 返回数量限制，默认 20
    /// - Returns: WikiSearchResponse
    func search(
        query: String,
        start: Int = 0,
        limit: Int = 20
    ) async throws -> WikiSearchResponse {
        let url = "\(baseURL)/rest/api/search"
        
        let parameters: Parameters = [
            "cql": "siteSearch ~ \"\(query)\" AND type in (\"space\",\"user\",\"page\",\"blogpost\",\"attachment\")",
            "start": "\(start)",
            "limit": "\(limit)",
            "excerpt": "highlight",
            "expand": "space.icon",
            "includeArchivedSpaces": "false",
            "src": "next.ui.search"
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            AF.request(url, method: .get, parameters: parameters, headers: defaultHeaders)
                .validate(statusCode: 200..<300)
                .responseDecodable(of: WikiSearchResponse.self) { response in
                    switch response.result {
                    case .success(let searchResponse):
                        continuation.resume(returning: searchResponse)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
        }
    }
    
    // MARK: - View Page API
    
    /// 获取页面 HTML 内容
    /// - Parameter pageId: 页面 ID
    /// - Returns: 页面 HTML 字符串
    func viewPage(pageId: String) async throws -> String {
        let url = "\(baseURL)/pages/viewpage.action"
        
        let parameters: Parameters = [
            "pageId": pageId
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            AF.request(url, method: .get, parameters: parameters, headers: defaultHeaders)
                .validate(statusCode: 200..<300)
                .responseString { response in
                    switch response.result {
                    case .success(let html):
                        continuation.resume(returning: html)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
        }
    }
    
    /// 获取页面 HTML 内容
    /// - Parameter url: 页面地址
    /// - Returns: 页面 HTML 字符串
    func viewPage(url: String) async throws -> String {
        
        return try await withCheckedThrowingContinuation { continuation in
            AF.request(url, method: .get, parameters: nil, headers: defaultHeaders)
                .validate(statusCode: 200..<300)
                .responseString { response in
                    switch response.result {
                    case .success(let html):
                        continuation.resume(returning: html)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
        }
    }
    
    /// 通过完整 URL 下载图片
    /// - Parameter url: 完整的图片 URL
    /// - Returns: 图片 Data
    func downloadImage(from url: String) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            AF.request(url, method: .get, headers: defaultHeaders)
                .validate(statusCode: 200..<300)
                .responseData { response in
                    switch response.result {
                    case .success(let data):
                        continuation.resume(returning: data)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
        }
    }
}

// MARK: - Error Types

enum WikiAPIError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingFailed(Error)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingFailed(let error):
            return "Decoding failed: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
