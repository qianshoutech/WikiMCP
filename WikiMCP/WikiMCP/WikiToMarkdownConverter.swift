//
//  WikiToMarkdownConverter.swift
//  WikiMCP
//
//  Created by phoenix on 2025/12/15.
//

import Foundation
import SwiftSoup

// MARK: - Wiki to Markdown Converter

/// 将 Confluence Wiki HTML 转换为 Markdown 格式
final class WikiToMarkdownConverter {
    
    private let baseURL: String
    
    init(baseURL: String = "https://wiki.p1.cn") {
        self.baseURL = baseURL
    }
    
    // MARK: - Public API
    
    /// 从 Wiki 页面 URL 转换为 Markdown
    /// - Parameter url: Wiki 页面 URL
    /// - Returns: Markdown 字符串
    func convert(url: String) async throws -> String {
        let html = try await WikiAPIClient.shared.viewPage(url: url)
        return try convertHTML(html)
    }
    
    /// 从 Wiki 页面 ID 转换为 Markdown
    /// - Parameter pageId: Wiki 页面 ID
    /// - Returns: Markdown 字符串
    func convert(pageId: String) async throws -> String {
        let html = try await WikiAPIClient.shared.viewPage(pageId: pageId)
        return try convertHTML(html)
    }
    
    /// 将 HTML 字符串转换为 Markdown
    /// - Parameter html: 完整的 HTML 页面
    /// - Returns: Markdown 字符串
    func convertHTML(_ html: String) throws -> String {
        let document = try SwiftSoup.parse(html)
        
        var markdownParts: [String] = []
        
        // 提取页面标题
        if let pageTitle = try document.select("meta[name=ajs-page-title]").first()?.attr("content"),
           !pageTitle.isEmpty {
            markdownParts.append("# \(pageTitle)")
            markdownParts.append("")
        }
        
        // 提取主要内容
        if let mainContent = try document.select("#main-content.wiki-content").first() {
            let contentMarkdown = try convertElement(mainContent)
            markdownParts.append(contentMarkdown)
        }
        
        // 提取评论部分
        let commentsMarkdown = try extractComments(document)
        if !commentsMarkdown.isEmpty {
            markdownParts.append("")
            markdownParts.append("---")
            markdownParts.append("")
            markdownParts.append("## 评论")
            markdownParts.append("")
            markdownParts.append(commentsMarkdown)
        }
        
        return markdownParts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Element Conversion
    
    private func convertElement(_ element: Element) throws -> String {
        var result = ""
        
        for child in element.getChildNodes() {
            if let textNode = child as? TextNode {
                let text = textNode.getWholeText()
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    result += text
                }
            } else if let childElement = child as? Element {
                result += try convertSingleElement(childElement)
            }
        }
        
        return result
    }
    
    private func convertSingleElement(_ element: Element) throws -> String {
        let tagName = element.tagName().lowercased()
        
        switch tagName {
        // 标题 h1-h6 (标题内的样式应该被忽略，使用纯文本)
        case "h1":
            return try "# \(extractPlainText(element))\n\n"
        case "h2":
            return try "## \(extractPlainText(element))\n\n"
        case "h3":
            return try "### \(extractPlainText(element))\n\n"
        case "h4":
            return try "#### \(extractPlainText(element))\n\n"
        case "h5":
            return try "##### \(extractPlainText(element))\n\n"
        case "h6":
            return try "###### \(extractPlainText(element))\n\n"
            
        // 段落
        case "p":
            let content = try convertInlineContent(element)
            if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "\n"
            }
            return "\(content)\n\n"
            
        // 引用
        case "blockquote":
            let content = try convertElement(element).trimmingCharacters(in: .whitespacesAndNewlines)
            let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
            let quotedLines = lines.map { "> \($0)" }.joined(separator: "\n")
            return "\(quotedLines)\n\n"
            
        // 无序列表
        case "ul":
            if element.hasClass("inline-task-list") {
                return try convertTaskList(element)
            }
            return try convertUnorderedList(element)
            
        // 有序列表
        case "ol":
            return try convertOrderedList(element)
            
        // 列表项
        case "li":
            return try convertInlineContent(element)
            
        // 表格
        case "table":
            return try convertTable(element)
            
        // 表格包装器
        case "div":
            if element.hasClass("table-wrap") {
                if let table = try element.select("table").first() {
                    return try convertTable(table)
                }
            }
            // 代码块
            if element.hasClass("code") && element.hasClass("panel") {
                return try convertCodeBlock(element)
            }
            // 内容包装器，递归处理
            if element.hasClass("content-wrapper") {
                return try convertElement(element)
            }
            // 普通 div
            return try convertElement(element)
            
        // 代码块 (pre)
        case "pre":
            return try convertPreBlock(element)
            
        // 内联代码
        case "code":
            let code = try element.text()
            return "`\(code)`"
            
        // 换行
        case "br":
            return "\n"
            
        // 水平线
        case "hr":
            return "\n---\n\n"
            
        // 图片
        case "img":
            return try convertImage(element)
            
        // 链接
        case "a":
            return try convertLink(element)
            
        // 加粗
        case "strong", "b":
            let content = try convertInlineContent(element)
            return "**\(content)**"
            
        // 斜体
        case "em", "i":
            let content = try convertInlineContent(element)
            return "*\(content)*"
            
        // 下划线 (Markdown 不支持，使用 HTML 标签)
        case "u":
            let content = try convertInlineContent(element)
            return "<u>\(content)</u>"
            
        // 删除线
        case "s", "del", "strike":
            let content = try convertInlineContent(element)
            return "~~\(content)~~"
            
        // span 处理颜色和其他样式
        case "span":
            return try convertSpan(element)
            
        // time 标签
        case "time":
            let datetime = try element.attr("datetime")
            let text = try element.text()
            return text.isEmpty ? datetime : text
            
        // colgroup 和 col 忽略
        case "colgroup", "col":
            return ""
            
        // tbody, thead, tr, th, td 由表格处理函数处理
        case "tbody", "thead":
            return try convertElement(element)
            
        // fieldset 忽略
        case "fieldset":
            return ""
            
        default:
            // 未知标签，递归处理子元素
            return try convertElement(element)
        }
    }
    
    // MARK: - Plain Text Extraction
    
    /// 提取纯文本，忽略所有格式
    private func extractPlainText(_ element: Element) throws -> String {
        return try element.text().trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Inline Content Conversion
    
    private func convertInlineContent(_ element: Element, inheritedStyles: Set<String> = []) throws -> String {
        var result = ""
        
        for child in element.getChildNodes() {
            if let textNode = child as? TextNode {
                result += textNode.getWholeText()
            } else if let childElement = child as? Element {
                let tagName = childElement.tagName().lowercased()
                
                switch tagName {
                case "strong", "b":
                    result += try convertFormattedContent(childElement, style: "bold", inheritedStyles: inheritedStyles)
                case "em", "i":
                    result += try convertFormattedContent(childElement, style: "italic", inheritedStyles: inheritedStyles)
                case "u":
                    // 下划线用 HTML 标签
                    let content = try convertInlineContent(childElement, inheritedStyles: inheritedStyles)
                    result += "<u>\(content)</u>"
                case "s", "del", "strike":
                    result += try convertFormattedContent(childElement, style: "strike", inheritedStyles: inheritedStyles)
                case "code":
                    let code = try childElement.text()
                    result += "`\(code)`"
                case "a":
                    result += try convertLink(childElement)
                case "img":
                    result += try convertImage(childElement)
                case "span":
                    result += try convertSpan(childElement, inheritedStyles: inheritedStyles)
                case "br":
                    result += "\n"
                case "time":
                    let datetime = try childElement.attr("datetime")
                    let text = try childElement.text()
                    result += text.isEmpty ? datetime : text
                default:
                    result += try convertInlineContent(childElement, inheritedStyles: inheritedStyles)
                }
            }
        }
        
        return result
    }
    
    /// 处理格式化内容，支持嵌套格式
    private func convertFormattedContent(_ element: Element, style: String, inheritedStyles: Set<String>) throws -> String {
        var result = ""
        var newStyles = inheritedStyles
        newStyles.insert(style)
        
        // 检查是否有嵌套格式元素
        let hasNestedFormatting = element.children().contains { child in
            let tag = child.tagName().lowercased()
            return ["strong", "b", "em", "i", "s", "del", "strike"].contains(tag)
        }
        
        if hasNestedFormatting {
            // 有嵌套格式，逐个处理子节点
            for child in element.getChildNodes() {
                if let textNode = child as? TextNode {
                    let text = textNode.getWholeText()
                    if !text.isEmpty {
                        // 纯文本部分，应用当前样式
                        result += applyMarkdownStyle(text, styles: newStyles)
                    }
                } else if let childElement = child as? Element {
                    let tagName = childElement.tagName().lowercased()
                    
                    switch tagName {
                    case "strong", "b":
                        result += try convertFormattedContent(childElement, style: "bold", inheritedStyles: newStyles)
                    case "em", "i":
                        result += try convertFormattedContent(childElement, style: "italic", inheritedStyles: newStyles)
                    case "s", "del", "strike":
                        result += try convertFormattedContent(childElement, style: "strike", inheritedStyles: newStyles)
                    case "u":
                        let content = try convertInlineContent(childElement, inheritedStyles: newStyles)
                        result += "<u>\(content)</u>"
                    default:
                        let content = try convertInlineContent(childElement, inheritedStyles: newStyles)
                        result += applyMarkdownStyle(content, styles: newStyles)
                    }
                }
            }
        } else {
            // 没有嵌套格式，直接处理
            let content = try convertInlineContent(element, inheritedStyles: newStyles)
            result = applyMarkdownStyle(content, styles: newStyles)
        }
        
        return result
    }
    
    /// 应用 Markdown 样式
    private func applyMarkdownStyle(_ text: String, styles: Set<String>) -> String {
        guard !text.isEmpty else { return "" }
        
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return text }
        
        let leadingSpaces = String(text.prefix(while: { $0.isWhitespace }))
        let trailingSpaces = String(text.reversed().prefix(while: { $0.isWhitespace }).reversed())
        
        var prefix = ""
        var suffix = ""
        
        // 删除线
        if styles.contains("strike") {
            prefix += "~~"
            suffix = "~~" + suffix
        }
        
        // 加粗和斜体组合
        let hasBold = styles.contains("bold")
        let hasItalic = styles.contains("italic")
        
        if hasBold && hasItalic {
            prefix += "***"
            suffix = "***" + suffix
        } else if hasBold {
            prefix += "**"
            suffix = "**" + suffix
        } else if hasItalic {
            prefix += "*"
            suffix = "*" + suffix
        }
        
        return "\(leadingSpaces)\(prefix)\(trimmed)\(suffix)\(trailingSpaces)"
    }
    
    // MARK: - Span Conversion (处理颜色等)
    
    private func convertSpan(_ element: Element, inheritedStyles: Set<String> = []) throws -> String {
        let style = try element.attr("style")
        let content = try convertInlineContent(element, inheritedStyles: inheritedStyles)
        
        // 如果有颜色样式，使用斜体表示
        if style.contains("color:") {
            var newStyles = inheritedStyles
            newStyles.insert("italic")
            return applyMarkdownStyle(content, styles: newStyles)
        }
        
        return content
    }
    
    // MARK: - Image Conversion
    
    private func convertImage(_ element: Element) throws -> String {
        // 优先使用 data-image-src 属性 (Confluence 使用此属性存储原始图片路径)
        var src = try element.attr("data-image-src")
        if src.isEmpty {
            src = try element.attr("src")
        }
        
        // 如果是相对路径，拼接 baseURL
        if !src.isEmpty && !src.hasPrefix("http") {
            src = baseURL + src
        }
        
        let alt = try element.attr("alt")
        let title = try element.attr("data-linked-resource-default-alias")
        
        let altText = alt.isEmpty ? (title.isEmpty ? "image" : title) : alt
        
        return "![\(altText)](\(src))"
    }
    
    // MARK: - Link Conversion
    
    private func convertLink(_ element: Element) throws -> String {
        var href = try element.attr("href")
        let text = try convertInlineContent(element)
        
        // 如果是相对路径，拼接 baseURL
        if !href.isEmpty && !href.hasPrefix("http") && !href.hasPrefix("#") && !href.hasPrefix("mailto:") {
            href = baseURL + href
        }
        
        // 如果链接文字为空，使用 href
        let linkText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if linkText.isEmpty {
            return href
        }
        
        return "[\(linkText)](\(href))"
    }
    
    // MARK: - List Conversion
    
    private func convertUnorderedList(_ element: Element, level: Int = 0) throws -> String {
        var result = ""
        let indent = String(repeating: "  ", count: level)
        
        for li in element.children() where li.tagName().lowercased() == "li" {
            var itemContent = ""
            
            for child in li.getChildNodes() {
                if let textNode = child as? TextNode {
                    itemContent += textNode.getWholeText()
                } else if let childElement = child as? Element {
                    let childTag = childElement.tagName().lowercased()
                    if childTag == "ul" {
                        // 嵌套无序列表
                        itemContent += "\n" + (try convertUnorderedList(childElement, level: level + 1))
                    } else if childTag == "ol" {
                        // 嵌套有序列表
                        itemContent += "\n" + (try convertOrderedList(childElement, level: level + 1))
                    } else {
                        itemContent += try convertSingleElement(childElement)
                    }
                }
            }
            
            let cleanContent = itemContent.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanContent.contains("\n") && !cleanContent.hasPrefix("  ") {
                // 处理多行内容
                result += "\(indent)- \(cleanContent)\n"
            } else {
                result += "\(indent)- \(cleanContent)\n"
            }
        }
        
        if level == 0 {
            result += "\n"
        }
        
        return result
    }
    
    private func convertOrderedList(_ element: Element, level: Int = 0) throws -> String {
        var result = ""
        let indent = String(repeating: "  ", count: level)
        var index = 1
        
        for li in element.children() where li.tagName().lowercased() == "li" {
            var itemContent = ""
            
            for child in li.getChildNodes() {
                if let textNode = child as? TextNode {
                    itemContent += textNode.getWholeText()
                } else if let childElement = child as? Element {
                    let childTag = childElement.tagName().lowercased()
                    if childTag == "ul" {
                        itemContent += "\n" + (try convertUnorderedList(childElement, level: level + 1))
                    } else if childTag == "ol" {
                        itemContent += "\n" + (try convertOrderedList(childElement, level: level + 1))
                    } else {
                        itemContent += try convertSingleElement(childElement)
                    }
                }
            }
            
            let cleanContent = itemContent.trimmingCharacters(in: .whitespacesAndNewlines)
            result += "\(indent)\(index). \(cleanContent)\n"
            index += 1
        }
        
        if level == 0 {
            result += "\n"
        }
        
        return result
    }
    
    // MARK: - Task List Conversion
    
    private func convertTaskList(_ element: Element) throws -> String {
        var result = ""
        
        for li in element.children() where li.tagName().lowercased() == "li" {
            let isChecked = li.hasClass("checked")
            let checkbox = isChecked ? "[x]" : "[ ]"
            let content = try convertInlineContent(li).trimmingCharacters(in: .whitespacesAndNewlines)
            result += "- \(checkbox) \(content)\n"
        }
        
        result += "\n"
        return result
    }
    
    // MARK: - Table Conversion
    
    private func convertTable(_ element: Element) throws -> String {
        var rows: [[String]] = []
        var headerRow: [String] = []
        var isHeader = false
        
        // 获取所有行
        let allRows = try element.select("tr")
        
        for (rowIndex, tr) in allRows.enumerated() {
            var cells: [String] = []
            
            for cell in tr.children() {
                let tagName = cell.tagName().lowercased()
                if tagName == "th" || tagName == "td" {
                    let cellContent = try convertTableCellContent(cell)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "\n", with: "<br>")
                        .replacingOccurrences(of: "|", with: "\\|")
                    cells.append(cellContent)
                    
                    if tagName == "th" {
                        isHeader = true
                    }
                }
            }
            
            if rowIndex == 0 && isHeader {
                headerRow = cells
            } else if rowIndex == 0 && !isHeader {
                // 第一行不是 header，创建空 header
                headerRow = cells.map { _ in "" }
                rows.append(cells)
            } else {
                rows.append(cells)
            }
        }
        
        // 如果没有行，返回空
        if headerRow.isEmpty && rows.isEmpty {
            return ""
        }
        
        // 如果只有数据行没有 header，使用第一行作为 header
        if headerRow.isEmpty && !rows.isEmpty {
            headerRow = rows.removeFirst()
        }
        
        // 构建 Markdown 表格
        var result = ""
        
        // Header 行
        result += "| " + headerRow.joined(separator: " | ") + " |\n"
        
        // 分隔行
        let separatorCells = headerRow.map { _ in "---" }
        result += "| " + separatorCells.joined(separator: " | ") + " |\n"
        
        // 数据行
        for row in rows {
            // 确保每行单元格数量一致
            var paddedRow = row
            while paddedRow.count < headerRow.count {
                paddedRow.append("")
            }
            result += "| " + paddedRow.prefix(headerRow.count).joined(separator: " | ") + " |\n"
        }
        
        result += "\n"
        return result
    }
    
    /// 处理表格单元格内容，保持列表格式
    private func convertTableCellContent(_ element: Element) throws -> String {
        var result = ""
        
        for child in element.getChildNodes() {
            if let textNode = child as? TextNode {
                let text = textNode.getWholeText()
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    result += text
                }
            } else if let childElement = child as? Element {
                let tagName = childElement.tagName().lowercased()
                
                switch tagName {
                case "ul":
                    // 无序列表在表格中用 • 代替
                    let items = try childElement.select("li")
                    let itemTexts = try items.map { li -> String in
                        try convertInlineContent(li).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    result += itemTexts.map { "• \($0)" }.joined(separator: "\n")
                    
                case "ol":
                    // 有序列表在表格中用数字
                    let items = try childElement.select("li")
                    var index = 1
                    var itemTexts: [String] = []
                    for li in items {
                        let text = try convertInlineContent(li).trimmingCharacters(in: .whitespacesAndNewlines)
                        itemTexts.append("\(index). \(text)")
                        index += 1
                    }
                    result += itemTexts.joined(separator: "\n")
                    
                case "div":
                    if childElement.hasClass("content-wrapper") {
                        result += try convertTableCellContent(childElement)
                    } else {
                        result += try convertSingleElement(childElement)
                    }
                    
                case "p":
                    let content = try convertInlineContent(childElement)
                    result += content
                    
                default:
                    result += try convertSingleElement(childElement)
                }
            }
        }
        
        return result
    }
    
    // MARK: - Code Block Conversion
    
    private func convertCodeBlock(_ element: Element) throws -> String {
        // 查找 pre 标签
        if let pre = try element.select("pre").first() {
            return try convertPreBlock(pre)
        }
        return try convertElement(element)
    }
    
    private func convertPreBlock(_ element: Element) throws -> String {
        // 获取语言
        var language = ""
        let params = try element.attr("data-syntaxhighlighter-params")
        if !params.isEmpty {
            // 解析 brush: xxx
            let regex = try NSRegularExpression(pattern: "brush:\\s*(\\w+)", options: [])
            if let match = regex.firstMatch(in: params, options: [], range: NSRange(params.startIndex..., in: params)) {
                if let range = Range(match.range(at: 1), in: params) {
                    language = String(params[range])
                }
            }
        }
        
        // 获取代码内容
        let code = try element.text()
        
        return "```\(language)\n\(code)\n```\n\n"
    }
    
    // MARK: - Comments Extraction
    
    private func extractComments(_ document: Document) throws -> String {
        var comments: [String] = []
        
        // 只选择顶级评论线程
        let commentThreads = try document.select("#page-comments > .comment-thread")
        
        for thread in commentThreads {
            let threadComments = try extractCommentsFromThread(thread, level: 0)
            comments.append(contentsOf: threadComments)
        }
        
        return comments.joined(separator: "\n")
    }
    
    private func extractCommentsFromThread(_ thread: Element, level: Int) throws -> [String] {
        var comments: [String] = []
        // 使用多层引用 > 来表示嵌套
        let quotePrefix = String(repeating: "> ", count: level + 1)
        
        // 获取当前评论（直接子元素）
        for child in thread.children() {
            if child.hasClass("comment") {
                // 获取作者
                let author = try child.select(".comment-header .author a").first()?.text() ?? "Unknown"
                
                // 获取内容
                let content = try child.select(".comment-content.wiki-content").first()
                let commentText = content != nil ? try convertElement(content!).trimmingCharacters(in: .whitespacesAndNewlines) : ""
                
                // 获取时间
                let time = try child.select(".comment-date a").first()?.text() ?? ""
                
                if !commentText.isEmpty {
                    comments.append("\(quotePrefix)**\(author)** (\(time)):")
                    let contentLines = commentText.split(separator: "\n", omittingEmptySubsequences: false)
                    for line in contentLines {
                        comments.append("\(quotePrefix)\(line)")
                    }
                    comments.append("")
                }
            } else if child.hasClass("comment-threads") {
                // 递归处理子评论线程
                for childThread in child.children() where childThread.hasClass("comment-thread") {
                    let childComments = try extractCommentsFromThread(childThread, level: level + 1)
                    comments.append(contentsOf: childComments)
                }
            }
        }
        
        return comments
    }
}

