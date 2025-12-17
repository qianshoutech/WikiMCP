#!/bin/bash

# WikiMCP Release Build Script
# 构建发布版本并打包（MCP + Skill 两种方式）

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

MCP_BINARY="wikimcp"
CLI_BINARY="wikicli"
BUILD_DIR="release-builds"
SKILL_DIR="skills"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  WikiMCP Release Build${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 清理旧的构建
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# ========================================
# 1. 构建 MCP 版本
# ========================================
echo -e "${BLUE}[1/4] Building MCP server (wikimcp)...${NC}"
swift build -c release --product $MCP_BINARY

# 复制 MCP 二进制文件并打包
cp .build/release/$MCP_BINARY "$BUILD_DIR/$MCP_BINARY"
cd "$BUILD_DIR"
tar -czvf "${MCP_BINARY}.tar.gz" "$MCP_BINARY"
rm "$MCP_BINARY"
cd ..
echo -e "${GREEN}✓ MCP build completed${NC}"
echo ""

# ========================================
# 2. 构建 Skill (CLI) 版本
# ========================================
echo -e "${BLUE}[2/4] Building CLI tool (wikicli)...${NC}"
swift build -c release --product $CLI_BINARY
echo -e "${GREEN}✓ CLI build completed${NC}"
echo ""

# ========================================
# 3. 打包 Skill
# ========================================
echo -e "${BLUE}[3/4] Packaging Skill...${NC}"

# 复制 wiki-tool 目录到 release-builds
cp -r "$SKILL_DIR/wiki-tool" "$BUILD_DIR/"

# 复制 wikicli 到 wiki-tool 目录
cp .build/release/$CLI_BINARY "$BUILD_DIR/wiki-tool/$CLI_BINARY"

# 创建 skill 压缩包
cd "$BUILD_DIR"
tar -czvf "wiki-tool.tar.gz" "wiki-tool"
rm -rf "wiki-tool"
cd ..
echo -e "${GREEN}✓ Skill packaging completed${NC}"
echo ""

# ========================================
# 4. 完成
# ========================================
echo -e "${BLUE}[4/4] Build summary${NC}"
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ✅ All builds completed!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Output files:${NC}"
ls -lh "$BUILD_DIR/"
echo ""
echo -e "${YELLOW}Release assets:${NC}"
echo -e "  1. ${BLUE}${MCP_BINARY}.tar.gz${NC}  - MCP server (for Cursor/Claude Code MCP)"
echo -e "  2. ${BLUE}wiki-tool.tar.gz${NC}     - Skill package (for Claude Code Agent Skill)"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Create a GitHub release"
echo -e "  2. Upload both .tar.gz files as release assets"
echo ""
