# WikiMCP

一个用于将 Confluence Wiki 页面转换为 Markdown 格式的 MCP (Model Context Protocol) 服务器。

## 功能

WikiMCP 提供两个 MCP 工具：

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

## 配置 MCP 客户端

### Cursor IDE

在 Cursor 的 MCP 配置文件中添加（macOS: `~/.cursor/mcp.json`）：

```json
{
  "mcpServers": {
    "wikimcp": {
      "command": "/path/to/WikiMCP/.build/release/wikimcp"
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
      "command": "/path/to/WikiMCP/.build/release/wikimcp"
    }
  }
}
```

## 使用示例

配置完成后，在支持 MCP 的客户端中可以使用以下工具：

### 搜索 Wiki
```
请搜索关于 "API 文档" 的 Wiki 页面
```

### 转换页面为 Markdown
```
请将 https://wiki.p1.cn/pages/viewpage.action?pageId=12345 转换为 Markdown
```

或

```
请将页面 ID 为 12345 的 Wiki 页面转换为 Markdown
```

## 项目结构

```
WikiMCP/
├── Package.swift           # SPM 包配置
├── Sources/
│   └── WikiMCP/
│       ├── main.swift                    # MCP 服务器入口
│       ├── WikiRequest.swift             # Wiki API 客户端
│       └── WikiToMarkdownConverter.swift # HTML -> Markdown 转换器
└── README.md
```

## 技术栈

- **Swift 6.0+** - 主要编程语言
- **[MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk)** - Model Context Protocol 官方 Swift SDK
- **[SwiftSoup](https://github.com/scinfu/SwiftSoup)** - HTML 解析库
- **[Alamofire](https://github.com/Alamofire/Alamofire)** - 网络请求库

## 注意事项

1. 需要有效的 Wiki 访问权限（Cookie 认证）
2. 当前 Cookie 配置在 `WikiRequest.swift` 中，生产环境需要修改为动态配置
3. 服务器通过 stdio 与 MCP 客户端通信

## License

MIT License
