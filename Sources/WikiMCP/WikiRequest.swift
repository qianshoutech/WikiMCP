//
//  WikiRequest.swift
//  WikiMCP
//
//  Created by phoenix on 2025/12/15.
//

import Foundation
import Alamofire
import Logging

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
    let _expandable: WikiExpandable?
    
    enum CodingKeys: String, CodingKey {
        case id, type, status, title, _expandable
    }
}

struct WikiExpandable: Codable {
    let space: String?
}

struct WikiContainer: Codable {
    let title: String?
    let displayUrl: String?
}



// MARK: - Wiki API Client

final class WikiAPIClient: @unchecked Sendable {
    
    static let shared = WikiAPIClient()
    
    private let baseURL = "https://wiki.p1.cn"
    
    /// Cookie 管理器
    private let cookieManager = CookieManager.shared
    
    /// 日志记录器
    private let logger = Logger(label: "com.wikimcp.api")
    
    /// 获取请求头（包含动态获取的 Cookie）
    private var defaultHeaders: HTTPHeaders {
        var headers: HTTPHeaders = [:]
        
        if let cookie = cookieManager.getCookie() {
            headers["Cookie"] = cookie
        } else {
            logger.warning("无法获取 Cookie，API 请求可能会失败")
        }
        
        return headers
    }
    
    private init() {
        // 初始化时检查 Cookie 状态
        if let cookie = cookieManager.getCookie(), !cookie.isEmpty {
            logger.info("已从环境变量 WIKI_COOKIE 加载 Cookie")
        } else {
            logger.warning("未配置 Cookie，请设置环境变量 WIKI_COOKIE")
        }
    }
    
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
