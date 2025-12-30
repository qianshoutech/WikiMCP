//
//  main.swift
//  WikiCLI
//
//  Created by phoenix on 2025/12/16.
//
//  命令行工具，用于 Agent Skill 调用
//  用法:
//    wikicli convert --url <url> [--browser <browser>]
//    wikicli convert --page-id <id> [--browser <browser>]
//    wikicli search --query <query> [--limit <limit>] [--browser <browser>]
//

import Foundation
import WikiCore

// MARK: - CLI Entry Point

struct WikiCLI {
    static func run() async {
        let arguments = CommandLine.arguments
        
        guard arguments.count >= 2 else {
            printUsage()
            exit(1)
        }
        
        let command = arguments[1]
        
        switch command {
        case "convert":
            await handleConvert(arguments: Array(arguments.dropFirst(2)))
        case "search":
            await handleSearch(arguments: Array(arguments.dropFirst(2)))
        case "help", "--help", "-h":
            printUsage()
        default:
            printError("未知命令: \(command)")
            printUsage()
            exit(1)
        }
    }
    
    // MARK: - Command Handlers
    
    static func handleConvert(arguments: [String]) async {
        var url: String?
        var pageId: String?
        var browser: String = "chrome"
        
        var i = 0
        while i < arguments.count {
            switch arguments[i] {
            case "--url", "-u":
                if i + 1 < arguments.count {
                    url = arguments[i + 1]
                    i += 2
                } else {
                    printError("--url 需要参数")
                    exit(1)
                }
            case "--page-id", "-p":
                if i + 1 < arguments.count {
                    pageId = arguments[i + 1]
                    i += 2
                } else {
                    printError("--page-id 需要参数")
                    exit(1)
                }
            case "--browser", "-b":
                if i + 1 < arguments.count {
                    browser = arguments[i + 1]
                    i += 2
                } else {
                    printError("--browser 需要参数")
                    exit(1)
                }
            default:
                // 如果第一个参数看起来像 URL，直接当作 URL
                if i == 0 && (arguments[i].hasPrefix("http") || arguments[i].contains("wiki.p1.cn")) {
                    url = arguments[i]
                    i += 1
                } else {
                    printError("未知参数: \(arguments[i])")
                    exit(1)
                }
            }
        }
        
        guard url != nil || pageId != nil else {
            printError("必须提供 --url 或 --page-id 参数")
            exit(1)
        }
        
        // 设置浏览器类型
        CookieManager.shared.setBrowser(browser)
        
        do {
            let converter = WikiToMarkdownConverter()
            let result: WikiConversionResult
            
            if let url = url {
                result = try await converter.convertAndSave(url: url)
            } else if let pageId = pageId {
                result = try await converter.convertAndSave(pageId: pageId)
            } else {
                printError("无效的参数")
                exit(1)
            }
            
            // 输出结果
            print("## 转换完成\n")
            print("**Markdown 文件**: `\(result.markdownFile.path)`\n")
            print("**输出目录**: `\(result.outputDirectory.path)`\n")
            if !result.downloadedImages.isEmpty {
                print("**下载图片数量**: \(result.downloadedImages.count)\n")
            }
            print("---\n")
            print(result.markdown)
            
        } catch {
            printError("转换失败: \(error.localizedDescription)")
            exit(1)
        }
    }
    
    static func handleSearch(arguments: [String]) async {
        var query: String?
        var limit = 10
        var browser: String = "chrome"
        
        var i = 0
        while i < arguments.count {
            switch arguments[i] {
            case "--query", "-q":
                if i + 1 < arguments.count {
                    query = arguments[i + 1]
                    i += 2
                } else {
                    printError("--query 需要参数")
                    exit(1)
                }
            case "--limit", "-l":
                if i + 1 < arguments.count {
                    limit = min(max(Int(arguments[i + 1]) ?? 10, 1), 50)
                    i += 2
                } else {
                    printError("--limit 需要参数")
                    exit(1)
                }
            case "--browser", "-b":
                if i + 1 < arguments.count {
                    browser = arguments[i + 1]
                    i += 2
                } else {
                    printError("--browser 需要参数")
                    exit(1)
                }
            default:
                // 如果是第一个参数且不是选项，当作 query
                if i == 0 && !arguments[i].hasPrefix("-") {
                    query = arguments[i]
                    i += 1
                } else {
                    printError("未知参数: \(arguments[i])")
                    exit(1)
                }
            }
        }
        
        guard let searchQuery = query, !searchQuery.isEmpty else {
            printError("必须提供 --query 参数")
            exit(1)
        }
        
        // 设置浏览器类型
        CookieManager.shared.setBrowser(browser)
        
        do {
            let response = try await WikiAPIClient.shared.search(query: searchQuery, limit: limit)
            
            // 格式化搜索结果
            print("## 搜索结果: \"\(searchQuery)\"\n")
            print("找到 \(response.totalSize) 条结果，显示前 \(response.results.count) 条:\n")
            
            for (index, result) in response.results.enumerated() {
                let title = result.title ?? result.content?.title ?? "无标题"
                let excerpt = result.excerpt?.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression) ?? ""
                let lastModified = result.friendlyLastModified ?? result.lastModified ?? ""
                let author = result.resultGlobalContainer?.title ?? result.content?._expandable?.space ?? ""
                
                print("### \(index + 1). \(title)")
                if !author.isEmpty {
                    print("- **作者**: \(author)")
                }
                if !lastModified.isEmpty {
                    print("- **最后修改**: \(lastModified)")
                }
                if !excerpt.isEmpty {
                    print("- **摘要**: \(excerpt.trimmingCharacters(in: .whitespacesAndNewlines))")
                }
                if let url = result.url {
                    print("- **URL**: https://wiki.p1.cn\(url)")
                }
                print("")
            }
            
        } catch {
            printError("搜索失败: \(error.localizedDescription)")
            exit(1)
        }
    }
    
    // MARK: - Helpers
    
    static func printUsage() {
        let browserList = CookieManager.supportedBrowsers.joined(separator: ", ")
        let usage = """
        WikiCLI - Wiki 命令行工具 (用于 Agent Skill)
        
        用法:
          wikicli convert --url <url>           将 Wiki 页面转换为 Markdown
          wikicli convert --page-id <id>        通过页面 ID 转换
          wikicli convert <url>                 简写形式
          wikicli search --query <关键词>       搜索 Wiki 内容
          wikicli search <关键词>               简写形式
          wikicli search --query <关键词> --limit <数量>
        
        选项:
          --url, -u       Wiki 页面 URL
          --page-id, -p   Wiki 页面 ID
          --query, -q     搜索关键词
          --limit, -l     搜索结果数量限制 (默认 10, 最大 50)
          --browser, -b   浏览器类型 (默认 chrome)
        
        支持的浏览器:
          \(browserList)
        
        示例:
          wikicli convert "https://wiki.p1.cn/pages/viewpage.action?pageId=12345"
          wikicli convert "https://wiki.p1.cn/..." --browser safari
          wikicli search "API 文档"
          wikicli search --query "部署指南" --limit 20 --browser edge
        
        注意:
          - Chromium 系浏览器可能会触发钥匙串访问提示（Chrome Safe Storage），请选择"始终允许"
          - Safari 需要开启"完全磁盘访问权限"
        """
        print(usage)
    }
    
    static func printError(_ message: String) {
        FileHandle.standardError.write("错误: \(message)\n".data(using: .utf8)!)
    }
}

// MARK: - Entry Point

// 使用 Task 启动异步主函数
Task {
    await WikiCLI.run()
    exit(0)
}

// 保持 RunLoop 运行
RunLoop.main.run()
