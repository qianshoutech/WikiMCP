---
name: wiki-tool
description: 访问公司内部 Confluence Wiki 文档。当用户提到 wiki.p1.cn、内部文档、公司Wiki、知识库，或需要搜索/查看公司内部文档时使用此 Skill。
allowed-tools: Read, Grep, Glob, Bash
---

# Wiki 文档工具

此 Skill 提供访问公司内部 Confluence Wiki (wiki.p1.cn) 的能力。

## 工具位置

所有文件位于此 Skill 目录（SKILL.md 同级目录）:

- 二进制文件: `wikicli`
- 配置文件: `env`

## 环境配置

Cookie 已配置在 `env` 文件中，使用时通过 `source` 命令加载。

## 命令用法

**注意**: 以下命令中 `{SKILL_DIR}` 表示此 SKILL.md 所在目录的路径。

### 1. 将 Wiki 页面转换为 Markdown

```bash
# 加载配置并通过 URL 转换
source {SKILL_DIR}/env && {SKILL_DIR}/wikicli convert "https://wiki.p1.cn/pages/viewpage.action?pageId=12345"

# 通过页面 ID 转换
source {SKILL_DIR}/env && {SKILL_DIR}/wikicli convert --page-id 12345
```

### 2. 搜索 Wiki 内容

```bash
# 基本搜索
source {SKILL_DIR}/env && {SKILL_DIR}/wikicli search "关键词"

# 带参数搜索
source {SKILL_DIR}/env && {SKILL_DIR}/wikicli search --query "API 文档" --limit 20
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

## 注意事项

1. **Cookie 有效性**: Cookie 可能会过期，如果请求失败请提示用户更新 Cookie
2. **网络依赖**: 需要能访问 wiki.p1.cn 的网络环境
3. **图片下载**: convert 命令会自动下载页面中的图片到本地
4. **搜索限制**: 搜索结果最多返回 50 条

## 常见问题处理

### 请求失败

- 检查 WIKI_COOKIE 环境变量是否设置
- 检查 Cookie 是否过期
- 检查网络连接

### 找不到内容

- 尝试不同的搜索关键词
- 检查 URL 或页面 ID 是否正确
