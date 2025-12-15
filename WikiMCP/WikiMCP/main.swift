//
//  main.swift
//  WikiMCP
//
//  Created by phoenix on 2025/12/15.
//

import Foundation
import ArgumentParser
import AppKit

struct WikiParser: ParsableCommand {
    
    static let configuration = CommandConfiguration(
        commandName: "WikiMCP",
        abstract: "将 Confluence Wiki 页面转换为 Markdown"
    )
    
    @Argument(help: "Wiki 页面 URL 或页面 ID")
    var input: String = "https://wiki.p1.cn/pages/viewpage.action?pageId=87451209"
    
    @Flag(name: .shortAndLong, help: "输出原始 HTML")
    var html: Bool = false
    
    @Flag(name: .shortAndLong, help: "保存到本地（下载图片）")
    var save: Bool = false
    
    func run() throws {
        Task {
            do {
                let converter = WikiToMarkdownConverter()
                
                if html {
                    // 输出原始 HTML
                    let htmlContent: String
                    if input.hasPrefix("http") {
                        htmlContent = try await WikiAPIClient.shared.viewPage(url: input)
                    } else {
                        htmlContent = try await WikiAPIClient.shared.viewPage(pageId: input)
                    }
                    print(htmlContent)
                } else if save {
                    // 保存到本地（下载图片）
                    print("正在转换并保存...")
                    
                    let result: WikiConversionResult
                    if input.hasPrefix("http") {
                        result = try await converter.convertAndSave(url: input)
                    } else {
                        result = try await converter.convertAndSave(pageId: input)
                    }
                    
                    print("")
                    print("========== 转换完成 ==========")
                    print("📁 输出目录: \(result.outputDirectory.path)")
                    print("📄 Markdown 文件: \(result.markdownFile.path)")
                    print("🖼️  下载图片数量: \(result.downloadedImages.count)")
                    print("==============================")
                    print("")
                    print("========== Markdown 内容 ==========")
                    print(result.markdown)
                    print("===================================")
                    
                } else {
                    // 仅输出 Markdown（图片使用远程 URL）
                    let markdown: String
                    if input.hasPrefix("http") {
                        markdown = try await converter.convert(url: input)
                    } else {
                        markdown = try await converter.convert(pageId: input)
                    }
                    
                    print("========== Markdown 输出 ==========")
                    print(markdown)
                    print("===================================")
                }
                
            } catch {
                print("转换失败: \(error)")
            }
            
            // 退出程序
            Foundation.exit(0)
        }
    }
}

WikiParser.main()
RunLoop.main.run()
