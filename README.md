# WikiMCP

一个用于访问 Confluence Wiki 的工具，支持 **MCP** 和 **Agent Skill** 两种方式接入。

## 功能

- **wiki_to_md** / **convert**: 将 Wiki 页面转换为 Markdown 格式
- **search_wiki** / **search**: 搜索 Wiki 内容


## 使用示例

### 搜索 Wiki
```
在 wiki 中搜索 Swift
```

### 获取页面内容
```
获取 https://wiki.p1.cn/pages/viewpage.action?pageId=12345
```

---

## 下载安装

### 方式一：MCP Server

```bash
# 一键安装
curl -fsSL https://raw.githubusercontent.com/qianshoutech/WikiMCP/main/install.sh | bash
```
#### 配置 MCP 客户端

在 Cursor 或其他 MCP 客户端的配置文件中添加：

```json
{
  "mcpServers": {
    "wikimcp": {
      "command": "~/.local/bin/wikimcp",
      "env": {
        "WIKI_COOKIE": "your_cookie_string_here"
      }
    }
  }
}
```

#### MCP 工具

| 工具 | 描述 | 参数 |
|------|------|------|
| `wiki_to_md` | 转换 Wiki 页面为 Markdown | `url` 或 `pageId` |
| `search_wiki` | 搜索 Wiki 内容 | `query`, `limit`(可选) |

---

### 方式二：Agent Skill

[![Download Skill](https://img.shields.io/badge/Download-wiki--tool.tar.gz-green?style=for-the-badge)](https://github.com/qianshoutech/WikiMCP/releases/latest/download/wiki-tool.tar.gz)

下载解压后, 在 `env` 中配置 Cookie, 然后将 `wiki-tool` 文件夹移动到 `~/.claude/skills`, 或项目中的的 `.claude/skills` 目录

目录结构：
```
your-project/
└── skills/
    └── wiki-tool/
        ├── SKILL.md    # Skill 定义
        ├── wikicli     # CLI 工具
        └── env         # 环境变量示例
```

#### 配置环境变量

编辑 `skills/wiki-tool/env` 文件，设置你的 Cookie：

```bash
export WIKI_COOKIE="your_cookie_string_here"
```

#### CLI 命令

```bash
# 搜索
source skills/wiki-tool/env && skills/wiki-tool/wikicli search "关键词"

# 转换页面
source skills/wiki-tool/env && skills/wiki-tool/wikicli convert "https://wiki.p1.cn/..."
```

---

## Cookie 配置

两种方式都需要有效的 Cookie 才能访问 Wiki。

### 如何获取 Cookie

1. 在浏览器中打开 https://wiki.p1.cn 并登录
2. 打开开发者工具 (F12 或 Cmd+Option+I)
3. 切换到 Network 标签
4. 刷新页面，点击任意请求
5. 在 Headers 中找到 `Cookie` 字段并复制完整内容

![示例](get_cookie.jpg)

---


## 项目结构

```
WikiMCP/
├── Sources/
│   ├── WikiCore/          # 核心功能库
│   ├── WikiMCP/           # MCP 服务器
│   └── WikiCLI/           # CLI 工具
├── skills/
│   └── wiki-tool/         # Skill 定义
├── scripts/
│   └── build-release.sh   # 发布构建脚本
└── README.md
```

## 注意事项

1. 需要有效的 Wiki 访问权限（Cookie 认证）
2. Cookie 过期后需要重新获取
3. 仅支持 macOS

## License

MIT License
