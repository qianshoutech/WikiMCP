#!/bin/bash

# WikiMCP Release Build Script
# 构建发布版本并打包

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

BINARY_NAME="wikimcp"
BUILD_DIR="release-builds"

echo -e "${BLUE}Building WikiMCP for release...${NC}"

# 清理旧的构建
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Release 构建
swift build -c release

# 复制二进制文件
cp .build/release/$BINARY_NAME "$BUILD_DIR/$BINARY_NAME"

# 创建 tar.gz 包
cd "$BUILD_DIR"
tar -czvf "${BINARY_NAME}.tar.gz" "$BINARY_NAME"
rm "$BINARY_NAME"
cd ..

echo ""
echo -e "${GREEN}✅ Build completed!${NC}"
echo -e "${BLUE}Output: $BUILD_DIR/${BINARY_NAME}.tar.gz${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Create a GitHub release"
echo -e "  2. Upload $BUILD_DIR/${BINARY_NAME}.tar.gz as release asset"
echo ""

# 显示文件信息
ls -lh "$BUILD_DIR/"

