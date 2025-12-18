#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Wiki API 请求模块

提供 Confluence Wiki API 的访问能力：
- 搜索 Wiki 内容
- 获取页面 HTML
- 下载图片
"""

import os
import sys
import warnings
from dataclasses import dataclass, field
from typing import Optional, List, Dict, Any

import requests
from requests.packages.urllib3.exceptions import InsecureRequestWarning

# 禁用 SSL 警告（内网服务器可能使用自签名证书）
warnings.simplefilter('ignore', InsecureRequestWarning)


# MARK: - Data Models

@dataclass
class WikiExpandable:
    """Wiki 可扩展字段"""
    space: Optional[str] = None


@dataclass
class WikiContent:
    """Wiki 内容信息"""
    id: Optional[str] = None
    type: Optional[str] = None
    status: Optional[str] = None
    title: Optional[str] = None
    expandable: Optional[WikiExpandable] = None

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'WikiContent':
        expandable = None
        if '_expandable' in data:
            expandable = WikiExpandable(space=data['_expandable'].get('space'))
        return cls(
            id=data.get('id'),
            type=data.get('type'),
            status=data.get('status'),
            title=data.get('title'),
            expandable=expandable
        )


@dataclass
class WikiContainer:
    """Wiki 容器信息"""
    title: Optional[str] = None
    display_url: Optional[str] = None

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'WikiContainer':
        return cls(
            title=data.get('title'),
            display_url=data.get('displayUrl')
        )


@dataclass
class WikiSearchResult:
    """Wiki 搜索结果项"""
    content: Optional[WikiContent] = None
    title: Optional[str] = None
    excerpt: Optional[str] = None
    url: Optional[str] = None
    result_global_container: Optional[WikiContainer] = None
    entity_type: Optional[str] = None
    icon_css_class: Optional[str] = None
    last_modified: Optional[str] = None
    friendly_last_modified: Optional[str] = None

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'WikiSearchResult':
        content = None
        if 'content' in data and data['content']:
            content = WikiContent.from_dict(data['content'])
        
        container = None
        if 'resultGlobalContainer' in data and data['resultGlobalContainer']:
            container = WikiContainer.from_dict(data['resultGlobalContainer'])
        
        return cls(
            content=content,
            title=data.get('title'),
            excerpt=data.get('excerpt'),
            url=data.get('url'),
            result_global_container=container,
            entity_type=data.get('entityType'),
            icon_css_class=data.get('iconCssClass'),
            last_modified=data.get('lastModified'),
            friendly_last_modified=data.get('friendlyLastModified')
        )


@dataclass
class WikiSearchResponse:
    """Wiki 搜索响应"""
    results: List[WikiSearchResult] = field(default_factory=list)
    start: int = 0
    limit: int = 20
    total_size: int = 0
    cql_query: Optional[str] = None
    search_duration: Optional[int] = None

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'WikiSearchResponse':
        results = [WikiSearchResult.from_dict(r) for r in data.get('results', [])]
        return cls(
            results=results,
            start=data.get('start', 0),
            limit=data.get('limit', 20),
            total_size=data.get('totalSize', 0),
            cql_query=data.get('cqlQuery'),
            search_duration=data.get('searchDuration')
        )


# MARK: - API Client

class WikiAPIClient:
    """Wiki API 客户端"""
    
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance
    
    def __init__(self):
        if self._initialized:
            return
        
        self.base_url = "https://wiki.p1.cn"
        self._cookie = os.environ.get('WIKI_COOKIE')
        self._session = requests.Session()
        self._session.verify = False  # 禁用 SSL 证书验证
        
        if not self._cookie:
            print("警告: 未设置 WIKI_COOKIE 环境变量，API 请求可能会失败", file=sys.stderr)
        
        self._initialized = True
    
    @property
    def _headers(self) -> Dict[str, str]:
        """获取请求头"""
        headers = {}
        if self._cookie:
            headers['Cookie'] = self._cookie
        return headers
    
    # MARK: - Search API
    
    def search(self, query: str, start: int = 0, limit: int = 20) -> WikiSearchResponse:
        """
        搜索 Wiki 内容
        
        Args:
            query: 搜索关键词
            start: 起始位置，默认 0
            limit: 返回数量限制，默认 20
            
        Returns:
            WikiSearchResponse
        """
        url = f"{self.base_url}/rest/api/search"
        
        params = {
            'cql': f'siteSearch ~ "{query}" AND type in ("space","user","page","blogpost","attachment")',
            'start': str(start),
            'limit': str(limit),
            'excerpt': 'highlight',
            'expand': 'space.icon',
            'includeArchivedSpaces': 'false',
            'src': 'next.ui.search'
        }
        
        response = self._session.get(url, params=params, headers=self._headers)
        response.raise_for_status()
        
        return WikiSearchResponse.from_dict(response.json())
    
    # MARK: - View Page API
    
    def view_page_by_id(self, page_id: str) -> str:
        """
        通过页面 ID 获取 HTML 内容
        
        Args:
            page_id: 页面 ID
            
        Returns:
            页面 HTML 字符串
        """
        url = f"{self.base_url}/pages/viewpage.action"
        params = {'pageId': page_id}
        
        response = self._session.get(url, params=params, headers=self._headers)
        response.raise_for_status()
        
        return response.text
    
    def view_page_by_url(self, page_url: str) -> str:
        """
        通过 URL 获取页面 HTML 内容
        
        Args:
            page_url: 页面完整 URL
            
        Returns:
            页面 HTML 字符串
        """
        response = self._session.get(page_url, headers=self._headers)
        response.raise_for_status()
        
        return response.text
    
    # MARK: - Image Download
    
    def download_image(self, url: str) -> bytes:
        """
        下载图片
        
        Args:
            url: 图片完整 URL
            
        Returns:
            图片二进制数据
        """
        response = self._session.get(url, headers=self._headers)
        response.raise_for_status()
        
        return response.content


# MARK: - Error Types

class WikiAPIError(Exception):
    """Wiki API 错误基类"""
    pass


class InvalidURLError(WikiAPIError):
    """无效 URL 错误"""
    pass


class NoDataError(WikiAPIError):
    """无数据错误"""
    pass


class NetworkError(WikiAPIError):
    """网络错误"""
    def __init__(self, original_error: Exception):
        self.original_error = original_error
        super().__init__(f"网络错误: {original_error}")


# 单例实例
wiki_client = WikiAPIClient()

