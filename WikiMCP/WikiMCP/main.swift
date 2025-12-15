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
    
    @Argument(help: "Wiki 页面 URL 或页面 ID")
    var input: String = "https://wiki.p1.cn/pages/viewpage.action?pageId=87451209"
    
    @Flag(name: .shortAndLong, help: "输出原始 HTML")
    var html: Bool = false
    
    func run() throws {
        Task {
            do {
                let converter = WikiToMarkdownConverter()
                
                // 判断输入是 URL 还是页面 ID
                if html {
                    // 输出原始 HTML
                    let htmlContent: String
                    if input.hasPrefix("http") {
                        htmlContent = try await WikiAPIClient.shared.viewPage(url: input)
                    } else {
                        htmlContent = try await WikiAPIClient.shared.viewPage(pageId: input)
                    }
                    print(htmlContent)
                } else {
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
