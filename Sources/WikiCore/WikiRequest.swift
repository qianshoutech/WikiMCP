//
//  WikiRequest.swift
//  WikiCore
//
//  Created by phoenix on 2025/12/17.
//

import Foundation
import Alamofire

// MARK: - Search Response Models

public struct WikiSearchResponse: Codable, Sendable {
    public let results: [WikiSearchResult]
    public let start: Int
    public let limit: Int
    public let totalSize: Int
    public let cqlQuery: String?
    public let searchDuration: Int?
    
    enum CodingKeys: String, CodingKey {
        case results, start, limit, totalSize, cqlQuery, searchDuration
    }
}

public struct WikiSearchResult: Codable, Sendable {
    public let content: WikiContent?
    public let title: String?
    public let excerpt: String?
    public let url: String?
    public let resultGlobalContainer: WikiContainer?
    public let entityType: String?
    public let iconCssClass: String?
    public let lastModified: String?
    public let friendlyLastModified: String?
}

public struct WikiContent: Codable, Sendable {
    public let id: String?
    public let type: String?
    public let status: String?
    public let title: String?
    public let _expandable: WikiExpandable?
    
    enum CodingKeys: String, CodingKey {
        case id, type, status, title, _expandable
    }
}

public struct WikiExpandable: Codable, Sendable {
    public let space: String?
}

public struct WikiContainer: Codable, Sendable {
    public let title: String?
    public let displayUrl: String?
}

// MARK: - Wiki API Client

public final class WikiAPIClient: @unchecked Sendable {
    
    public static let shared = WikiAPIClient()
    
    private let baseURL = "https://wiki.p1.cn"
    
    /// Cookie 管理器
    private let cookieManager = CookieManager.shared
    
    /// 日志记录器
    private var logger: WikiLoggerProtocol {
        WikiLoggerConfig.shared.logger
    }
    
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
        if cookieManager.getCookie() == nil || cookieManager.getCookie()?.isEmpty == true {
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
    public func search(
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
    public func viewPage(pageId: String) async throws -> String {
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
    public func viewPage(url: String) async throws -> String {
        
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
    public func downloadImage(from url: String) async throws -> Data {
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

public enum WikiAPIError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingFailed(Error)
    case networkError(Error)
    
    public var errorDescription: String? {
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

