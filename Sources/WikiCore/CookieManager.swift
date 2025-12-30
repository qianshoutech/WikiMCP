//
//  CookieManager.swift
//  WikiCore
//
//  Created by phoenix on 2025/12/17.
//

import Foundation
import SweetCookieKit

// MARK: - Cookie Manager

/// Cookie 管理器
/// 从浏览器实时读取 cookie
public final class CookieManager: @unchecked Sendable {
    
    public static let shared = CookieManager()
    
    /// 当前使用的浏览器类型
    private var browser: Browser = .chrome
    
    /// Cookie 客户端
    private let client = BrowserCookieClient()
    
    private init() {}
    
    /// 设置浏览器类型
    public func setBrowser(_ browser: Browser) {
        self.browser = browser
    }
    
    /// 设置浏览器类型（通过字符串）
    public func setBrowser(_ typeName: String) {
        if let browser = Browser(rawValue: typeName) {
            self.browser = browser
        }
    }
    
    /// 获取 cookie（实时从浏览器读取）
    public func getCookie() -> String? {
        return getCookie(for: "wiki.p1.cn")
    }
    
    /// 获取指定域名的 cookie
    public func getCookie(for domain: String) -> String? {
        let stores = client.stores(for: browser)
        
        // 优先使用 Default profile
        guard let store = stores.first(where: { $0.profile.name == "Default" }) ?? stores.first else {
            return nil
        }
        
        let query = BrowserCookieQuery(domains: [domain])
        
        do {
            let records = try client.records(matching: query, in: store)
            
            // 过滤出需要的 cookie：seraph.confluence 和 qs_sso_auth_at
            let neededCookies = ["seraph.confluence", "qs_sso_auth_at"]
            let filteredRecords = records.filter { neededCookies.contains($0.name) }
            
            if filteredRecords.isEmpty {
                return nil
            }
            
            // 拼接 cookie 字符串
            let cookieString = filteredRecords
                .map { "\($0.name)=\($0.value)" }
                .joined(separator: "; ")
            
            return cookieString
        } catch {
            return nil
        }
    }
    
    /// 获取当前浏览器类型
    public func getCurrentBrowser() -> Browser {
        return browser
    }
    
    /// 支持的浏览器列表
    public static var supportedBrowsers: [String] {
        return [
            "safari", "chrome", "chromeBeta", "chromeCanary",
            "arc", "arcBeta", "arcCanary", "chatgptAtlas",
            "chromium", "firefox", "brave", "braveBeta", "braveNightly",
            "edge", "edgeBeta", "edgeCanary", "vivaldi"
        ]
    }
}
