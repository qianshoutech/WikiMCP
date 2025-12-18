#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
WikiCLI - Wiki 命令行工具 (用于 Agent Skill)

用法:
  python3 wikicli.py convert --url <url>
  python3 wikicli.py convert --page-id <id>
  python3 wikicli.py search --query <query> [--limit <limit>]
"""

import argparse
import re
import sys
from typing import Optional

from wiki_request import wiki_client, WikiSearchResponse
from wiki_converter import WikiToMarkdownConverter


def handle_convert(url: Optional[str] = None, page_id: Optional[str] = None) -> None:
    """处理 convert 命令"""
    if not url and not page_id:
        print("错误: 必须提供 --url 或 --page-id 参数", file=sys.stderr)
        sys.exit(1)
    
    try:
        converter = WikiToMarkdownConverter()
        result = converter.convert_and_save(url=url, page_id=page_id)
        
        # 输出结果
        print("## 转换完成\n")
        print(f"**Markdown 文件**: `{result.markdown_file}`\n")
        print(f"**输出目录**: `{result.output_directory}`\n")
        if result.downloaded_images:
            print(f"**下载图片数量**: {len(result.downloaded_images)}\n")
        print("---\n")
        print(result.markdown)
        
    except Exception as e:
        print(f"错误: 转换失败: {e}", file=sys.stderr)
        sys.exit(1)


def handle_search(query: str, limit: int = 10) -> None:
    """处理 search 命令"""
    if not query:
        print("错误: 必须提供 --query 参数", file=sys.stderr)
        sys.exit(1)
    
    # 限制 limit 范围
    limit = max(1, min(limit, 50))
    
    try:
        response: WikiSearchResponse = wiki_client.search(query=query, limit=limit)
        
        # 格式化搜索结果
        print(f'## 搜索结果: "{query}"\n')
        print(f"找到 {response.total_size} 条结果，显示前 {len(response.results)} 条:\n")
        
        for index, result in enumerate(response.results, 1):
            title = result.title or (result.content.title if result.content else None) or "无标题"
            
            # 清理 excerpt 中的 HTML 标签
            excerpt = result.excerpt or ""
            excerpt = re.sub(r'<[^>]+>', '', excerpt)
            
            last_modified = result.friendly_last_modified or result.last_modified or ""
            author = ""
            if result.result_global_container:
                author = result.result_global_container.title or ""
            elif result.content and result.content.expandable:
                author = result.content.expandable.space or ""
            
            print(f"### {index}. {title}")
            if author:
                print(f"- **作者**: {author}")
            if last_modified:
                print(f"- **最后修改**: {last_modified}")
            if excerpt:
                print(f"- **摘要**: {excerpt.strip()}")
            if result.url:
                print(f"- **URL**: https://wiki.p1.cn{result.url}")
            print("")
        
    except Exception as e:
        print(f"错误: 搜索失败: {e}", file=sys.stderr)
        sys.exit(1)


def main() -> None:
    """主入口"""
    parser = argparse.ArgumentParser(
        description='WikiCLI - Wiki 命令行工具 (用于 Agent Skill)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
示例:
  %(prog)s convert "https://wiki.p1.cn/pages/viewpage.action?pageId=12345"
  %(prog)s convert --page-id 12345
  %(prog)s search "API 文档"
  %(prog)s search --query "部署指南" --limit 20

环境变量:
  WIKI_COOKIE     Wiki 认证 Cookie (必需)
'''
    )
    
    subparsers = parser.add_subparsers(dest='command', help='可用命令')
    
    # convert 命令
    convert_parser = subparsers.add_parser('convert', help='将 Wiki 页面转换为 Markdown')
    convert_parser.add_argument('url_positional', nargs='?', help='Wiki 页面 URL (可直接作为位置参数)')
    convert_parser.add_argument('--url', '-u', help='Wiki 页面 URL')
    convert_parser.add_argument('--page-id', '-p', help='Wiki 页面 ID')
    
    # search 命令
    search_parser = subparsers.add_parser('search', help='搜索 Wiki 内容')
    search_parser.add_argument('query_positional', nargs='?', help='搜索关键词 (可直接作为位置参数)')
    search_parser.add_argument('--query', '-q', help='搜索关键词')
    search_parser.add_argument('--limit', '-l', type=int, default=10, help='搜索结果数量限制 (默认 10, 最大 50)')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        sys.exit(1)
    
    if args.command == 'convert':
        # 支持位置参数或 --url 参数
        url = args.url_positional or args.url
        page_id = args.page_id
        
        # 如果位置参数看起来像 URL
        if url and (url.startswith('http') or 'wiki.p1.cn' in url):
            handle_convert(url=url)
        elif page_id:
            handle_convert(page_id=page_id)
        elif url:
            # 可能是 page_id
            handle_convert(page_id=url)
        else:
            print("错误: 必须提供 --url 或 --page-id 参数", file=sys.stderr)
            sys.exit(1)
    
    elif args.command == 'search':
        # 支持位置参数或 --query 参数
        query = args.query_positional or args.query
        
        if not query:
            print("错误: 必须提供搜索关键词", file=sys.stderr)
            sys.exit(1)
        
        handle_search(query=query, limit=args.limit)


if __name__ == '__main__':
    main()

