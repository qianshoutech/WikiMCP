---
name: wiki-tool
description: 访问公司内部 Confluence Wiki 文档。当用户提到 wiki.p1.cn、内部文档、公司Wiki、知识库，或需要搜索/查看公司内部文档时使用此 Skill。
allowed-tools: Read, Grep, Glob, Bash
---

# Wiki 文档工具

此 Skill 提供访问公司内部 Confluence Wiki (wiki.p1.cn) 的能力。

## 工具位置

二进制文件位于此 Skill 目录（SKILL.md 同级目录）: `wikicli`

## Cookie 自动获取

**无需手动配置 Cookie！** 本工具会自动从本地浏览器读取 Cookie。

支持的浏览器：
- chrome (默认)
- safari
- chromeBeta, chromeCanary
- arc, arcBeta, arcCanary
- edge, edgeBeta, edgeCanary
- brave, braveBeta, braveNightly
- firefox, chromium, vivaldi, chatgptAtlas

## 命令用法

**注意**: 以下命令中 `{SKILL_DIR}` 表示此 SKILL.md 所在目录的路径。

### 1. 将 Wiki 页面转换为 Markdown

```bash
# 通过 URL 转换（使用默认 Chrome 浏览器）
{SKILL_DIR}/wikicli convert "https://wiki.p1.cn/pages/viewpage.action?pageId=12345"

# 通过页面 ID 转换
{SKILL_DIR}/wikicli convert --page-id 12345

# 使用其他浏览器
{SKILL_DIR}/wikicli convert "https://wiki.p1.cn/..." --browser safari
{SKILL_DIR}/wikicli convert --page-id 12345 --browser edge
```

### 2. 搜索 Wiki 内容

```bash
# 基本搜索
{SKILL_DIR}/wikicli search "关键词"

# 带参数搜索
{SKILL_DIR}/wikicli search --query "API 文档" --limit 20

# 使用其他浏览器
{SKILL_DIR}/wikicli search "关键词" --browser arc
```

## 使用流程

### 当用户发送 Wiki 链接时

1. 直接使用 `convert` 命令获取页面内容
2. 解读并总结关键信息给用户

### 当用户需要查找信息时

1. 先使用 `search` 命令搜索相关内容
2. 展示搜索结果供用户选择
3. 用户确认后使用 `convert` 获取详细内容

## 输出说明

### convert 命令输出

- Markdown 文件路径
- 输出目录路径
- 下载的图片数量
- 完整的 Markdown 内容

### search 命令输出

- 搜索结果总数
- 每条结果包含：标题、作者、最后修改时间、摘要、URL

## 首次使用注意事项

### Chromium 系浏览器（Chrome、Edge、Arc、Brave 等）

首次运行时，系统可能会弹出钥匙串访问提示：
> "xxx 想要访问你的钥匙串中的密钥 Chrome Safe Storage"

**请选择「始终允许」** 以避免每次运行都弹出提示。

### Safari 浏览器

需要在系统设置中为终端或运行环境开启「完全磁盘访问权限」：
1. 打开「系统设置」→「隐私与安全性」→「完全磁盘访问权限」
2. 添加并启用 Cursor 或你使用的终端应用

## 常见问题处理

### 请求失败

- 确认浏览器已登录 wiki.p1.cn
- 检查是否选择了正确的浏览器类型
- 对于 Safari，检查是否开启了完全磁盘访问权限
- 检查网络连接

### 钥匙串访问被拒绝

- 如果之前选择了「拒绝」，需要在「钥匙串访问」应用中手动删除该条目，然后重新运行

### 找不到内容

- 尝试不同的搜索关键词
- 检查 URL 或页面 ID 是否正确
