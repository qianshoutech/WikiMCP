//
//  WikiLogger.swift
//  WikiCore
//
//  Created by phoenix on 2025/12/17.
//

import Foundation

// MARK: - Wiki Logger Protocol

/// 日志协议，允许不同的实现方式
public protocol WikiLoggerProtocol: Sendable {
    func info(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)
}

// MARK: - Default Logger (stderr)

/// 默认日志实现，输出到 stderr
public final class StderrLogger: WikiLoggerProtocol, @unchecked Sendable {
    public static let shared = StderrLogger()
    
    private init() {}
    
    public func info(_ message: String) {
        FileHandle.standardError.write("ℹ️ \(message)\n".data(using: .utf8)!)
    }
    
    public func warning(_ message: String) {
        FileHandle.standardError.write("⚠️ 警告: \(message)\n".data(using: .utf8)!)
    }
    
    public func error(_ message: String) {
        FileHandle.standardError.write("❌ 错误: \(message)\n".data(using: .utf8)!)
    }
}

// MARK: - Silent Logger

/// 静默日志实现，不输出任何内容
public final class SilentLogger: WikiLoggerProtocol, @unchecked Sendable {
    public static let shared = SilentLogger()
    
    private init() {}
    
    public func info(_ message: String) {}
    public func warning(_ message: String) {}
    public func error(_ message: String) {}
}

// MARK: - Global Logger Configuration

/// 全局日志配置
public final class WikiLoggerConfig: @unchecked Sendable {
    public static let shared = WikiLoggerConfig()
    
    private var _logger: WikiLoggerProtocol = StderrLogger.shared
    private let lock = NSLock()
    
    private init() {}
    
    public var logger: WikiLoggerProtocol {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _logger
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _logger = newValue
        }
    }
}

