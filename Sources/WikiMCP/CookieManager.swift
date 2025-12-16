//
//  CookieManager.swift
//  WikiMCP
//
//  Created by phoenix on 2025/12/16.
//

import Foundation

// MARK: - Cookie Manager

/// Cookie 管理器
/// 从环境变量 WIKI_COOKIE 读取 cookie
final class CookieManager: @unchecked Sendable {
    
    static let shared = CookieManager()
    
    /// Cookie 值（从环境变量加载）
    private let cookie: String?
    
    private init() {
        cookie = ProcessInfo.processInfo.environment["WIKI_COOKIE"]
    }
    
    /// 获取 cookie
    func getCookie() -> String? {
        return cookie
    }
}
