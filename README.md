# WikiMCP

一个用于将 Confluence Wiki 页面转换为 Markdown 格式的 MCP (Model Context Protocol) 服务器。

## 功能

WikiMCP 提供以下 MCP 工具：

### 1. `wiki_to_md`
将 Confluence Wiki 页面转换为 Markdown 格式。

**参数：**
- `url` (可选): Wiki 页面的完整 URL，例如: `https://wiki.p1.cn/pages/viewpage.action?pageId=12345`
- `pageId` (可选): Wiki 页面的 ID，例如: `12345`

> 注意：`url` 和 `pageId` 至少需要提供一个。

### 2. `search_wiki`
搜索 Confluence Wiki 内容，返回匹配的页面列表。

**参数：**
- `query` (必需): 搜索关键词
- `limit` (可选): 返回结果数量限制，默认 10，最大 50

## 安装

### 从源码构建

1. 确保已安装 Swift 6.0+ (Xcode 16+)

2. 克隆仓库：
```bash
git clone <repository-url>
cd WikiMCP
```

3. 构建项目：
```bash
# Debug 构建
swift build

# Release 构建
swift build -c release
```

4. 构建后的可执行文件位于：
```bash
# Debug
.build/debug/wikimcp

# Release
.build/release/wikimcp
```

## Cookie 配置

WikiMCP 需要有效的 Cookie 才能访问 Wiki。通过环境变量 `WIKI_COOKIE` 配置（见下方 MCP 配置示例）。

### 如何获取 Cookie

1. 在浏览器中打开 https://wiki.p1.cn 并登录
2. 打开开发者工具 (F12 或 Cmd+Option+I, 或右键-检查)
3. 切换到 Network 标签
4. 刷新页面，点击页面请求
5. 在 Headers 中找到 `Cookie` 字段并复制完整内容配置到 mcp env 中
6. Cookie 如果过期请重新获取并配置

![示例](get_cookie.jpg)

## 配置 MCP 客户端

### Cursor IDE

**带环境变量配置 Cookie：**

```json
{
  "mcpServers": {
    "wikimcp": {
      "command": "/path/to/WikiMCP/.build/release/wikimcp",
      "env": {
        "WIKI_COOKIE": "your_cookie_string_here"
      }
    }
  }
}
```

将路径替换为实际的可执行文件路径。

### Claude Desktop

在 Claude Desktop 的配置文件中添加（macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`）：

```json
{
  "mcpServers": {
    "wikimcp": {
      "command": "/path/to/WikiMCP/.build/release/wikimcp",
      "env": {
        "WIKI_COOKIE": "your_cookie_string_here"
      }
    }
  }
}
```

## 使用示例

配置完成后，在支持 MCP 的客户端中可以使用以下工具：

### 搜索 Wiki
```
在wiki中搜索 Swift
```

### 转换页面为 Markdown
```
获取 https://wiki.p1.cn/pages/viewpage.action?pageId=12345
```


## 项目结构

```
WikiMCP/
├── Package.swift           # SPM 包配置
├── Sources/
│   └── WikiMCP/
│       ├── main.swift                    # MCP 服务器入口
│       ├── CookieManager.swift           # Cookie 管理器
│       ├── WikiRequest.swift             # Wiki API 客户端
│       └── WikiToMarkdownConverter.swift # HTML -> Markdown 转换器
└── README.md
```


## 注意事项

1. 需要有效的 Wiki 访问权限（Cookie 认证）
2. 推荐使用环境变量 `WIKI_COOKIE` 配置 Cookie

## License

MIT License
