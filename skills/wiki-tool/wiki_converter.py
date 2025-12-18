#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Wiki HTML 转 Markdown 转换器

将 Confluence Wiki HTML 页面转换为 Markdown 格式，
支持图片下载和本地保存。
"""

import os
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Set
from urllib.parse import unquote, urlparse

from bs4 import BeautifulSoup, NavigableString, Tag

from wiki_request import wiki_client


# MARK: - Data Models

@dataclass
class WikiConversionResult:
    """转换结果"""
    markdown: str
    output_directory: Path
    markdown_file: Path
    downloaded_images: Dict[str, Path] = field(default_factory=dict)


# MARK: - Wiki to Markdown Converter

class WikiToMarkdownConverter:
    """将 Confluence Wiki HTML 转换为 Markdown 格式"""
    
    def __init__(self, base_url: str = "https://wiki.p1.cn"):
        self.base_url = base_url
        
        # 缓存目录（Linux 使用 ~/.cache/WikiMCP）
        cache_base = os.environ.get('XDG_CACHE_HOME', os.path.expanduser('~/.cache'))
        self.cache_directory = Path(cache_base) / 'WikiMCP'
        
        # 当前转换任务的上下文
        self._current_page_id: Optional[str] = None
        self._current_page_title: Optional[str] = None
        self._current_output_dir: Optional[Path] = None
        self._images_to_download: List[Tuple[str, str]] = []
    
    # MARK: - Public API
    
    def convert(self, url: Optional[str] = None, page_id: Optional[str] = None) -> str:
        """
        从 Wiki 页面转换为 Markdown（仅返回字符串，不保存文件）
        
        Args:
            url: Wiki 页面 URL
            page_id: Wiki 页面 ID
            
        Returns:
            Markdown 字符串
        """
        if url:
            html = wiki_client.view_page_by_url(url)
        elif page_id:
            html = wiki_client.view_page_by_id(page_id)
        else:
            raise ValueError("必须提供 url 或 page_id 参数")
        
        return self._convert_html(html)
    
    def convert_and_save(self, url: Optional[str] = None, page_id: Optional[str] = None) -> WikiConversionResult:
        """
        从 Wiki 页面转换并保存为本地文件（下载图片）
        
        Args:
            url: Wiki 页面 URL
            page_id: Wiki 页面 ID
            
        Returns:
            WikiConversionResult 包含保存信息
        """
        if url:
            html = wiki_client.view_page_by_url(url)
        elif page_id:
            html = wiki_client.view_page_by_id(page_id)
        else:
            raise ValueError("必须提供 url 或 page_id 参数")
        
        return self._convert_and_save_html(html)
    
    # MARK: - Private Methods
    
    def _convert_and_save_html(self, html: str) -> WikiConversionResult:
        """转换 HTML 并保存到本地"""
        # 重置状态
        self._images_to_download = []
        
        soup = BeautifulSoup(html, 'lxml')
        
        # 提取页面信息
        page_title_meta = soup.select_one('meta[name="ajs-page-title"]')
        page_id_meta = soup.select_one('meta[name="ajs-page-id"]')
        
        page_title = page_title_meta.get('content', 'Untitled') if page_title_meta else 'Untitled'
        page_id = page_id_meta.get('content', 'unknown') if page_id_meta else 'unknown'
        
        self._current_page_id = page_id
        self._current_page_title = page_title
        
        # 创建输出目录
        safe_folder_name = self._make_safe_filename(f"{page_title}-{page_id}")
        output_dir = self.cache_directory / safe_folder_name
        self._current_output_dir = output_dir
        
        output_dir.mkdir(parents=True, exist_ok=True)
        
        # 转换为 Markdown
        markdown = self._convert_html_with_local_images(soup)
        
        # 下载所有图片
        downloaded_images: Dict[str, Path] = {}
        for image_url, local_name in self._images_to_download:
            try:
                image_data = wiki_client.download_image(image_url)
                local_path = output_dir / local_name
                local_path.write_bytes(image_data)
                downloaded_images[image_url] = local_path
                print(f"✓ 下载图片: {local_name}", file=sys.stderr)
            except Exception as e:
                print(f"✗ 下载图片失败: {image_url} - {e}", file=sys.stderr)
        
        # 保存 Markdown 文件
        safe_file_name = self._make_safe_filename(page_title)
        markdown_file = output_dir / f"{safe_file_name}.md"
        markdown_file.write_text(markdown, encoding='utf-8')
        
        # 重置状态
        self._current_page_id = None
        self._current_page_title = None
        self._current_output_dir = None
        self._images_to_download = []
        
        return WikiConversionResult(
            markdown=markdown,
            output_directory=output_dir,
            markdown_file=markdown_file,
            downloaded_images=downloaded_images
        )
    
    def _make_safe_filename(self, name: str) -> str:
        """生成安全的文件名"""
        invalid_chars = r'/\:*?"<>|'
        for char in invalid_chars:
            name = name.replace(char, '_')
        return name
    
    def _convert_html_with_local_images(self, soup: BeautifulSoup) -> str:
        """转换 HTML 并使用本地图片路径"""
        markdown_parts: List[str] = []
        
        # 提取页面标题
        page_title_meta = soup.select_one('meta[name="ajs-page-title"]')
        if page_title_meta:
            page_title = page_title_meta.get('content', '')
            if page_title:
                markdown_parts.append(f"# {page_title}")
                markdown_parts.append("")
        
        # 提取主要内容
        main_content = soup.select_one('#main-content.wiki-content')
        if main_content:
            content_markdown = self._convert_element(main_content)
            markdown_parts.append(content_markdown)
        
        # 提取评论部分
        comments_markdown = self._extract_comments(soup)
        if comments_markdown:
            markdown_parts.append("")
            markdown_parts.append("---")
            markdown_parts.append("")
            markdown_parts.append("## 评论")
            markdown_parts.append("")
            markdown_parts.append(comments_markdown)
        
        return '\n'.join(markdown_parts).strip()
    
    def _convert_html(self, html: str) -> str:
        """将 HTML 字符串转换为 Markdown"""
        soup = BeautifulSoup(html, 'lxml')
        
        markdown_parts: List[str] = []
        
        # 提取页面标题
        page_title_meta = soup.select_one('meta[name="ajs-page-title"]')
        if page_title_meta:
            page_title = page_title_meta.get('content', '')
            if page_title:
                markdown_parts.append(f"# {page_title}")
                markdown_parts.append("")
        
        # 提取主要内容
        main_content = soup.select_one('#main-content.wiki-content')
        if main_content:
            content_markdown = self._convert_element(main_content)
            markdown_parts.append(content_markdown)
        
        # 提取评论部分
        comments_markdown = self._extract_comments(soup)
        if comments_markdown:
            markdown_parts.append("")
            markdown_parts.append("---")
            markdown_parts.append("")
            markdown_parts.append("## 评论")
            markdown_parts.append("")
            markdown_parts.append(comments_markdown)
        
        return '\n'.join(markdown_parts).strip()
    
    # MARK: - Element Conversion
    
    def _convert_element(self, element: Tag) -> str:
        """转换元素及其子元素"""
        result = ""
        
        for child in element.children:
            if isinstance(child, NavigableString):
                text = str(child)
                if text.strip():
                    result += text
            elif isinstance(child, Tag):
                result += self._convert_single_element(child)
        
        return result
    
    def _convert_single_element(self, element: Tag) -> str:
        """转换单个元素"""
        tag_name = element.name.lower() if element.name else ''
        
        # 标题 h1-h6
        if tag_name == 'h1':
            return f"# {self._extract_plain_text(element)}\n\n"
        elif tag_name == 'h2':
            return f"## {self._extract_plain_text(element)}\n\n"
        elif tag_name == 'h3':
            return f"### {self._extract_plain_text(element)}\n\n"
        elif tag_name == 'h4':
            return f"#### {self._extract_plain_text(element)}\n\n"
        elif tag_name == 'h5':
            return f"##### {self._extract_plain_text(element)}\n\n"
        elif tag_name == 'h6':
            return f"###### {self._extract_plain_text(element)}\n\n"
        
        # 段落
        elif tag_name == 'p':
            content = self._convert_inline_content(element)
            if not content.strip():
                return "\n"
            return f"{content}\n\n"
        
        # 引用
        elif tag_name == 'blockquote':
            content = self._convert_element(element).strip()
            lines = content.split('\n')
            quoted_lines = [f"> {line}" for line in lines]
            return '\n'.join(quoted_lines) + "\n\n"
        
        # 无序列表
        elif tag_name == 'ul':
            if 'inline-task-list' in element.get('class', []):
                return self._convert_task_list(element)
            return self._convert_unordered_list(element)
        
        # 有序列表
        elif tag_name == 'ol':
            return self._convert_ordered_list(element)
        
        # 列表项
        elif tag_name == 'li':
            return self._convert_inline_content(element)
        
        # 表格
        elif tag_name == 'table':
            return self._convert_table(element)
        
        # 表格包装器 / div
        elif tag_name == 'div':
            if 'table-wrap' in element.get('class', []):
                table = element.select_one('table')
                if table:
                    return self._convert_table(table)
            # 代码块
            classes = element.get('class', [])
            if 'code' in classes and 'panel' in classes:
                return self._convert_code_block(element)
            # 内容包装器
            if 'content-wrapper' in classes:
                return self._convert_element(element)
            # 普通 div
            return self._convert_element(element)
        
        # 代码块 (pre)
        elif tag_name == 'pre':
            return self._convert_pre_block(element)
        
        # 内联代码
        elif tag_name == 'code':
            code = element.get_text()
            return f"`{code}`"
        
        # 换行
        elif tag_name == 'br':
            return "\n"
        
        # 水平线
        elif tag_name == 'hr':
            return "\n---\n\n"
        
        # 图片
        elif tag_name == 'img':
            return self._convert_image(element)
        
        # 链接
        elif tag_name == 'a':
            return self._convert_link(element)
        
        # 加粗
        elif tag_name in ('strong', 'b'):
            content = self._convert_inline_content(element)
            return f"**{content}**"
        
        # 斜体
        elif tag_name in ('em', 'i'):
            content = self._convert_inline_content(element)
            return f"*{content}*"
        
        # 下划线
        elif tag_name == 'u':
            content = self._convert_inline_content(element)
            return f"<u>{content}</u>"
        
        # 删除线
        elif tag_name in ('s', 'del', 'strike'):
            content = self._convert_inline_content(element)
            return f"~~{content}~~"
        
        # span
        elif tag_name == 'span':
            return self._convert_span(element)
        
        # time 标签
        elif tag_name == 'time':
            datetime = element.get('datetime', '')
            text = element.get_text()
            return text if text else datetime
        
        # 忽略的标签
        elif tag_name in ('colgroup', 'col', 'fieldset'):
            return ""
        
        # tbody, thead
        elif tag_name in ('tbody', 'thead'):
            return self._convert_element(element)
        
        # 默认：递归处理子元素
        else:
            return self._convert_element(element)
    
    # MARK: - Plain Text Extraction
    
    def _extract_plain_text(self, element: Tag) -> str:
        """提取纯文本，忽略所有格式"""
        return element.get_text().strip()
    
    # MARK: - Inline Content Conversion
    
    def _convert_inline_content(self, element: Tag, inherited_styles: Optional[Set[str]] = None) -> str:
        """转换内联内容"""
        if inherited_styles is None:
            inherited_styles = set()
        
        result = ""
        
        for child in element.children:
            if isinstance(child, NavigableString):
                result += str(child)
            elif isinstance(child, Tag):
                tag_name = child.name.lower() if child.name else ''
                
                if tag_name in ('strong', 'b'):
                    result += self._convert_formatted_content(child, 'bold', inherited_styles)
                elif tag_name in ('em', 'i'):
                    result += self._convert_formatted_content(child, 'italic', inherited_styles)
                elif tag_name == 'u':
                    content = self._convert_inline_content(child, inherited_styles)
                    result += f"<u>{content}</u>"
                elif tag_name in ('s', 'del', 'strike'):
                    result += self._convert_formatted_content(child, 'strike', inherited_styles)
                elif tag_name == 'code':
                    code = child.get_text()
                    result += f"`{code}`"
                elif tag_name == 'a':
                    result += self._convert_link(child)
                elif tag_name == 'img':
                    result += self._convert_image(child)
                elif tag_name == 'span':
                    result += self._convert_span(child, inherited_styles)
                elif tag_name == 'br':
                    result += "\n"
                elif tag_name == 'time':
                    datetime = child.get('datetime', '')
                    text = child.get_text()
                    result += text if text else datetime
                else:
                    result += self._convert_inline_content(child, inherited_styles)
        
        return result
    
    def _convert_formatted_content(self, element: Tag, style: str, inherited_styles: Set[str]) -> str:
        """处理格式化内容，支持嵌套格式"""
        new_styles = inherited_styles | {style}
        
        # 检查是否有嵌套格式元素
        has_nested_formatting = any(
            child.name and child.name.lower() in ('strong', 'b', 'em', 'i', 's', 'del', 'strike')
            for child in element.children
            if isinstance(child, Tag)
        )
        
        if has_nested_formatting:
            result = ""
            for child in element.children:
                if isinstance(child, NavigableString):
                    text = str(child)
                    if text:
                        result += self._apply_markdown_style(text, new_styles)
                elif isinstance(child, Tag):
                    tag_name = child.name.lower() if child.name else ''
                    
                    if tag_name in ('strong', 'b'):
                        result += self._convert_formatted_content(child, 'bold', new_styles)
                    elif tag_name in ('em', 'i'):
                        result += self._convert_formatted_content(child, 'italic', new_styles)
                    elif tag_name in ('s', 'del', 'strike'):
                        result += self._convert_formatted_content(child, 'strike', new_styles)
                    elif tag_name == 'u':
                        content = self._convert_inline_content(child, new_styles)
                        result += f"<u>{content}</u>"
                    else:
                        content = self._convert_inline_content(child, new_styles)
                        result += self._apply_markdown_style(content, new_styles)
            return result
        else:
            content = self._convert_inline_content(element, new_styles)
            return self._apply_markdown_style(content, new_styles)
    
    def _apply_markdown_style(self, text: str, styles: Set[str]) -> str:
        """应用 Markdown 样式"""
        if not text:
            return ""
        
        trimmed = text.strip()
        if not trimmed:
            return text
        
        leading_spaces = text[:len(text) - len(text.lstrip())]
        trailing_spaces = text[len(text.rstrip()):]
        
        prefix = ""
        suffix = ""
        
        # 删除线
        if 'strike' in styles:
            prefix += "~~"
            suffix = "~~" + suffix
        
        # 加粗和斜体组合
        has_bold = 'bold' in styles
        has_italic = 'italic' in styles
        
        if has_bold and has_italic:
            prefix += "***"
            suffix = "***" + suffix
        elif has_bold:
            prefix += "**"
            suffix = "**" + suffix
        elif has_italic:
            prefix += "*"
            suffix = "*" + suffix
        
        return f"{leading_spaces}{prefix}{trimmed}{suffix}{trailing_spaces}"
    
    # MARK: - Span Conversion
    
    def _convert_span(self, element: Tag, inherited_styles: Optional[Set[str]] = None) -> str:
        """处理 span 元素（颜色等）"""
        if inherited_styles is None:
            inherited_styles = set()
        
        style = element.get('style', '')
        content = self._convert_inline_content(element, inherited_styles)
        
        # 如果有颜色样式，使用斜体表示
        if 'color:' in style:
            new_styles = inherited_styles | {'italic'}
            return self._apply_markdown_style(content, new_styles)
        
        return content
    
    # MARK: - Image Conversion
    
    def _convert_image(self, element: Tag) -> str:
        """转换图片"""
        # 优先使用 data-image-src 属性
        src = element.get('data-image-src', '') or element.get('src', '')
        
        # 如果是相对路径，拼接 baseURL
        full_url = src
        if src and not src.startswith('http'):
            full_url = self.base_url + src
        
        alt = element.get('alt', '')
        title = element.get('data-linked-resource-default-alias', '')
        alt_text = alt if alt else (title if title else 'image')
        
        # 如果是保存模式，转换为本地路径
        if self._current_page_id and self._current_output_dir:
            local_name = self._generate_local_image_name(full_url, self._current_page_id)
            self._images_to_download.append((full_url, local_name))
            return f"![{alt_text}]({local_name})"
        
        return f"![{alt_text}]({full_url})"
    
    def _generate_local_image_name(self, url_string: str, page_id: str) -> str:
        """从 URL 生成本地图片文件名"""
        try:
            parsed = urlparse(url_string)
            path_parts = parsed.path.split('/')
            
            if 'attachments' in path_parts:
                idx = path_parts.index('attachments')
                if idx + 2 < len(path_parts):
                    attachment_page_id = path_parts[idx + 1]
                    filename = path_parts[idx + 2]
                    decoded_filename = unquote(filename).replace(' ', '_')
                    return f"{attachment_page_id}_{decoded_filename}"
            
            last_component = parsed.path.split('/')[-1]
            decoded_name = unquote(last_component).replace(' ', '_')
            
            if '.' in decoded_name:
                return f"{page_id}_{decoded_name}"
            else:
                return f"{page_id}_{decoded_name}.png"
        except Exception:
            return f"{page_id}_image.png"
    
    # MARK: - Link Conversion
    
    def _convert_link(self, element: Tag) -> str:
        """转换链接"""
        href = element.get('href', '')
        text = self._convert_inline_content(element)
        
        if href and not href.startswith(('http', '#', 'mailto:')):
            href = self.base_url + href
        
        link_text = text.strip()
        if not link_text:
            return href
        
        return f"[{link_text}]({href})"
    
    # MARK: - List Conversion
    
    def _convert_unordered_list(self, element: Tag, level: int = 0) -> str:
        """转换无序列表"""
        result = ""
        indent = "  " * level
        
        for li in element.children:
            if isinstance(li, Tag) and li.name and li.name.lower() == 'li':
                item_content = ""
                
                for child in li.children:
                    if isinstance(child, NavigableString):
                        item_content += str(child)
                    elif isinstance(child, Tag):
                        child_tag = child.name.lower() if child.name else ''
                        if child_tag == 'ul':
                            item_content += "\n" + self._convert_unordered_list(child, level + 1)
                        elif child_tag == 'ol':
                            item_content += "\n" + self._convert_ordered_list(child, level + 1)
                        else:
                            item_content += self._convert_single_element(child)
                
                clean_content = item_content.strip()
                result += f"{indent}- {clean_content}\n"
        
        if level == 0:
            result += "\n"
        
        return result
    
    def _convert_ordered_list(self, element: Tag, level: int = 0) -> str:
        """转换有序列表"""
        result = ""
        indent = "  " * level
        index = 1
        
        for li in element.children:
            if isinstance(li, Tag) and li.name and li.name.lower() == 'li':
                item_content = ""
                
                for child in li.children:
                    if isinstance(child, NavigableString):
                        item_content += str(child)
                    elif isinstance(child, Tag):
                        child_tag = child.name.lower() if child.name else ''
                        if child_tag == 'ul':
                            item_content += "\n" + self._convert_unordered_list(child, level + 1)
                        elif child_tag == 'ol':
                            item_content += "\n" + self._convert_ordered_list(child, level + 1)
                        else:
                            item_content += self._convert_single_element(child)
                
                clean_content = item_content.strip()
                result += f"{indent}{index}. {clean_content}\n"
                index += 1
        
        if level == 0:
            result += "\n"
        
        return result
    
    # MARK: - Task List Conversion
    
    def _convert_task_list(self, element: Tag) -> str:
        """转换任务列表"""
        result = ""
        
        for li in element.children:
            if isinstance(li, Tag) and li.name and li.name.lower() == 'li':
                is_checked = 'checked' in li.get('class', [])
                checkbox = "[x]" if is_checked else "[ ]"
                content = self._convert_inline_content(li).strip()
                result += f"- {checkbox} {content}\n"
        
        result += "\n"
        return result
    
    # MARK: - Table Conversion
    
    def _convert_table(self, element: Tag) -> str:
        """转换表格"""
        # 检查是否有嵌套表格
        has_nested_table = bool(element.select('td table, th table, td .table-wrap, th .table-wrap'))
        
        if has_nested_table:
            return self._convert_table_to_html(element)
        
        return self._convert_table_to_markdown(element)
    
    def _convert_table_to_markdown(self, element: Tag) -> str:
        """将表格转换为 Markdown 格式"""
        rows: List[List[str]] = []
        header_row: List[str] = []
        is_header = False
        
        direct_rows = self._get_direct_table_rows(element)
        
        for row_index, tr in enumerate(direct_rows):
            cells: List[str] = []
            
            for cell in tr.children:
                if isinstance(cell, Tag) and cell.name:
                    tag_name = cell.name.lower()
                    if tag_name in ('th', 'td'):
                        cell_content = self._convert_table_cell_content(cell)
                        cell_content = cell_content.strip().replace('\n', '<br>').replace('|', '\\|')
                        cells.append(cell_content)
                        
                        if tag_name == 'th':
                            is_header = True
            
            if row_index == 0 and is_header:
                header_row = cells
            elif row_index == 0 and not is_header:
                header_row = [""] * len(cells)
                rows.append(cells)
            else:
                rows.append(cells)
        
        if not header_row and not rows:
            return ""
        
        if not header_row and rows:
            header_row = rows.pop(0)
        
        result = ""
        result += "| " + " | ".join(header_row) + " |\n"
        separator_cells = ["---"] * len(header_row)
        result += "| " + " | ".join(separator_cells) + " |\n"
        
        for row in rows:
            padded_row = row + [""] * (len(header_row) - len(row))
            result += "| " + " | ".join(padded_row[:len(header_row)]) + " |\n"
        
        result += "\n"
        return result
    
    def _get_direct_table_rows(self, element: Tag) -> List[Tag]:
        """获取表格的直接行元素"""
        direct_rows: List[Tag] = []
        
        # BeautifulSoup 不支持 "> tbody" 选择器，手动查找直接子元素
        tbody = None
        thead = None
        for child in element.children:
            if isinstance(child, Tag):
                if child.name and child.name.lower() == 'tbody':
                    tbody = child
                elif child.name and child.name.lower() == 'thead':
                    thead = child
        
        if tbody is None:
            tbody = element
        
        if thead:
            for child in thead.children:
                if isinstance(child, Tag) and child.name and child.name.lower() == 'tr':
                    direct_rows.append(child)
        
        for child in tbody.children:
            if isinstance(child, Tag) and child.name and child.name.lower() == 'tr':
                direct_rows.append(child)
        
        return direct_rows
    
    def _convert_table_to_html(self, element: Tag) -> str:
        """将嵌套表格转换为 HTML 格式"""
        result = "\n<table>\n"
        
        direct_rows = self._get_direct_table_rows(element)
        
        for tr in direct_rows:
            result += "\n<tr>\n"
            
            for cell in tr.children:
                if isinstance(cell, Tag) and cell.name:
                    tag_name = cell.name.lower()
                    if tag_name in ('th', 'td'):
                        cell_content = self._convert_table_cell_to_html(cell)
                        result += f"\n<{tag_name}>\n\n{cell_content}\n\n</{tag_name}>\n"
            
            result += "\n</tr>\n"
        
        result += "\n</table>\n\n"
        return result
    
    def _convert_table_cell_to_html(self, element: Tag) -> str:
        """转换表格单元格为 HTML"""
        result = ""
        
        for child in element.children:
            if isinstance(child, NavigableString):
                text = str(child)
                if text.strip():
                    result += text
            elif isinstance(child, Tag):
                tag_name = child.name.lower() if child.name else ''
                
                if tag_name == 'table':
                    result += self._convert_table_to_html(child)
                elif tag_name == 'div':
                    classes = child.get('class', [])
                    if 'table-wrap' in classes:
                        nested_table = child.select_one('table')
                        if nested_table:
                            result += self._convert_table_to_html(nested_table)
                        else:
                            result += self._convert_table_cell_to_html(child)
                    elif 'content-wrapper' in classes:
                        result += self._convert_table_cell_to_html(child)
                    elif 'code' in classes and 'panel' in classes:
                        result += self._convert_code_block(child)
                    else:
                        result += self._convert_single_element(child)
                elif tag_name == 'pre':
                    result += self._convert_pre_block(child)
                elif tag_name == 'ul':
                    result += self._convert_unordered_list(child)
                elif tag_name == 'ol':
                    result += self._convert_ordered_list(child)
                elif tag_name == 'p':
                    content = self._convert_inline_content(child)
                    if content.strip():
                        result += content + "\n\n"
                elif tag_name == 'br':
                    result += "\n"
                else:
                    result += self._convert_single_element(child)
        
        return result.strip()
    
    def _convert_table_cell_content(self, element: Tag) -> str:
        """转换表格单元格内容"""
        result = ""
        
        for child in element.children:
            if isinstance(child, NavigableString):
                text = str(child)
                if text.strip():
                    result += text
            elif isinstance(child, Tag):
                tag_name = child.name.lower() if child.name else ''
                
                if tag_name == 'ul':
                    items = child.select('li')
                    item_texts = [self._convert_inline_content(li).strip() for li in items]
                    if result.strip():
                        result += "\n"
                    result += '\n'.join(f"• {text}" for text in item_texts)
                elif tag_name == 'ol':
                    items = child.select('li')
                    if result.strip():
                        result += "\n"
                    item_texts = [f"{i+1}. {self._convert_inline_content(li).strip()}" for i, li in enumerate(items)]
                    result += '\n'.join(item_texts)
                elif tag_name == 'div':
                    if 'content-wrapper' in child.get('class', []):
                        result += self._convert_table_cell_content(child)
                    else:
                        result += self._convert_single_element(child)
                elif tag_name == 'p':
                    content = self._convert_inline_content(child)
                    if result.strip() and content.strip():
                        result += "\n"
                    result += content
                elif tag_name == 'br':
                    result += "\n"
                else:
                    result += self._convert_single_element(child)
        
        return result
    
    # MARK: - Code Block Conversion
    
    def _convert_code_block(self, element: Tag) -> str:
        """转换代码块"""
        pre = element.select_one('pre')
        if pre:
            return self._convert_pre_block(pre)
        return self._convert_element(element)
    
    def _convert_pre_block(self, element: Tag) -> str:
        """转换 pre 块"""
        language = ""
        params = element.get('data-syntaxhighlighter-params', '')
        if params:
            match = re.search(r'brush:\s*(\w+)', params)
            if match:
                language = match.group(1)
        
        code = element.get_text()
        
        return f"```{language}\n{code}\n```\n\n"
    
    # MARK: - Comments Extraction
    
    def _extract_comments(self, soup: BeautifulSoup) -> str:
        """提取评论"""
        comments: List[str] = []
        
        comment_threads = soup.select('#page-comments > .comment-thread')
        
        for thread in comment_threads:
            thread_comments = self._extract_comments_from_thread(thread, 0)
            comments.extend(thread_comments)
        
        return '\n'.join(comments)
    
    def _extract_comments_from_thread(self, thread: Tag, level: int) -> List[str]:
        """从评论线程提取评论"""
        comments: List[str] = []
        quote_prefix = "> " * (level + 1)
        
        for child in thread.children:
            if isinstance(child, Tag):
                classes = child.get('class', [])
                
                if 'comment' in classes:
                    author_el = child.select_one('.comment-header .author a')
                    author = author_el.get_text() if author_el else 'Unknown'
                    
                    content_el = child.select_one('.comment-content.wiki-content')
                    comment_text = self._convert_element(content_el).strip() if content_el else ''
                    
                    time_el = child.select_one('.comment-date a')
                    time_str = time_el.get_text() if time_el else ''
                    
                    if comment_text:
                        comments.append(f"{quote_prefix}**{author}** ({time_str}):")
                        content_lines = comment_text.split('\n')
                        for line in content_lines:
                            comments.append(f"{quote_prefix}{line}")
                        comments.append("")
                
                elif 'comment-threads' in classes:
                    for child_thread in child.children:
                        if isinstance(child_thread, Tag) and 'comment-thread' in child_thread.get('class', []):
                            child_comments = self._extract_comments_from_thread(child_thread, level + 1)
                            comments.extend(child_comments)
        
        return comments

