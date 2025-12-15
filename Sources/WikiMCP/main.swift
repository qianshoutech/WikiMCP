//
//  main.swift
//  WikiMCP
//
//  Created by phoenix on 2025/12/15.
//

import Foundation
import MCP
import Logging

// MARK: - MCP Server Setup

/// Wiki MCP 服务器
/// 提供两个工具:
/// 1. wiki_to_md - 将 Wiki 页面转换为 Markdown
/// 2. search_wiki - 搜索 Wiki 内容

struct WikiMCPServer {
    static func main() async throws {
        // 配置日志（输出到 stderr，避免干扰 MCP 通信）
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardError(label: label)
            handler.logLevel = .warning
            return handler
        }
        
        let logger = Logger(label: "com.wikimcp.server")
        
        // 创建 MCP Server
        let server = Server(
            name: "WikiMCP",
            version: "1.0.0",
            capabilities: .init(
                tools: .init(listChanged: false)
            )
        )
        
        // 创建转换器实例
        let converter = WikiToMarkdownConverter()
        
        // MARK: - 注册工具列表处理器
        
        await server.withMethodHandler(ListTools.self) { _ in
            return .init(tools: [
                Tool(
                    name: "wiki_to_md",
                    description: "将 Confluence Wiki 页面转换为 Markdown 格式。支持通过 URL 或 pageId 获取页面内容。",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "url": .object([
                                "type": .string("string"),
                                "description": .string("Wiki 页面的完整 URL，例如: https://wiki.p1.cn/pages/viewpage.action?pageId=12345")
                            ]),
                            "pageId": .object([
                                "type": .string("string"),
                                "description": .string("Wiki 页面的 ID，例如: 12345")
                            ])
                        ])
                    ])
                ),
                Tool(
                    name: "search_wiki",
                    description: "搜索 Confluence Wiki 内容，返回匹配的页面列表。",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "query": .object([
                                "type": .string("string"),
                                "description": .string("搜索关键词")
                            ]),
                            "limit": .object([
                                "type": .string("integer"),
                                "description": .string("返回结果数量限制，默认 10，最大 50")
                            ])
                        ]),
                        "required": .array([.string("query")])
                    ])
                )
            ])
        }
        
        // MARK: - 注册工具调用处理器
        
        await server.withMethodHandler(CallTool.self) { params in
            let toolName = params.name
            let arguments = params.arguments ?? [:]
            
            switch toolName {
            case "wiki_to_md":
                return await handleWikiToMd(arguments: arguments, converter: converter)
                
            case "search_wiki":
                return await handleSearchWiki(arguments: arguments)
                
            default:
                return .init(
                    content: [.text("未知工具: \(toolName)")],
                    isError: true
                )
            }
        }
        
        // 创建 Stdio 传输层并启动服务器
        let transport = StdioTransport(logger: logger)
        
        logger.info("WikiMCP 服务器正在启动...")
        
        try await server.start(transport: transport)
        
        // 保持服务器运行
        try await Task.sleep(for: .seconds(365 * 24 * 60 * 60)) // 运行一年（实际上会被信号中断）
    }
    
    // MARK: - Tool Handlers
    
    /// 处理 wiki_to_md 工具调用
    static func handleWikiToMd(arguments: [String: Value], converter: WikiToMarkdownConverter) async -> CallTool.Result {
        do {
            let markdown: String
            
            // 优先使用 URL
            if let urlValue = arguments["url"], case .string(let url) = urlValue, !url.isEmpty {
                markdown = try await converter.convert(url: url)
            }
            // 其次使用 pageId
            else if let pageIdValue = arguments["pageId"], case .string(let pageId) = pageIdValue, !pageId.isEmpty {
                markdown = try await converter.convert(pageId: pageId)
            }
            else {
                return .init(
                    content: [.text("错误: 必须提供 url 或 pageId 参数")],
                    isError: true
                )
            }
            
            return .init(
                content: [.text(markdown)],
                isError: false
            )
            
        } catch {
            return .init(
                content: [.text("转换失败: \(error.localizedDescription)")],
                isError: true
            )
        }
    }
    
    /// 处理 search_wiki 工具调用
    static func handleSearchWiki(arguments: [String: Value]) async -> CallTool.Result {
        guard let queryValue = arguments["query"], case .string(let query) = queryValue, !query.isEmpty else {
            return .init(
                content: [.text("错误: 必须提供 query 参数")],
                isError: true
            )
        }
        
        // 解析 limit 参数
        var limit = 10
        if let limitValue = arguments["limit"] {
            switch limitValue {
            case .int(let l):
                limit = min(max(l, 1), 50)
            case .string(let s):
                if let l = Int(s) {
                    limit = min(max(l, 1), 50)
                }
            default:
                break
            }
        }
        
        do {
            let response = try await WikiAPIClient.shared.search(query: query, limit: limit)
            
            // 格式化搜索结果
            var resultText = "## 搜索结果: \"\(query)\"\n\n"
            resultText += "找到 \(response.totalSize) 条结果，显示前 \(response.results.count) 条:\n\n"
            
            for (index, result) in response.results.enumerated() {
                let title = result.title ?? result.content?.title ?? "无标题"
                let pageId = result.content?.id ?? "未知"
                let spaceName = result.content?.space?.name ?? "未知空间"
                let excerpt = result.excerpt?.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression) ?? ""
                let lastModified = result.friendlyLastModified ?? result.lastModified ?? ""
                
                resultText += "### \(index + 1). \(title)\n"
                resultText += "- **页面 ID**: \(pageId)\n"
                resultText += "- **空间**: \(spaceName)\n"
                if !lastModified.isEmpty {
                    resultText += "- **最后修改**: \(lastModified)\n"
                }
                if !excerpt.isEmpty {
                    resultText += "- **摘要**: \(excerpt.trimmingCharacters(in: .whitespacesAndNewlines))\n"
                }
                if let url = result.url {
                    resultText += "- **URL**: https://wiki.p1.cn\(url)\n"
                }
                resultText += "\n"
            }
            
            return .init(
                content: [.text(resultText)],
                isError: false
            )
            
        } catch {
            return .init(
                content: [.text("搜索失败: \(error.localizedDescription)")],
                isError: true
            )
        }
    }
}

// MARK: - Entry Point

// 使用 Task 启动异步主函数
Task {
    do {
        try await WikiMCPServer.main()
    } catch {
        FileHandle.standardError.write("启动失败: \(error)\n".data(using: .utf8)!)
        exit(1)
    }
}

// 保持 RunLoop 运行
RunLoop.main.run()
