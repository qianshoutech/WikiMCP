#!/bin/bash

# WikiMCP Installation Script
# https://github.com/qianshoutech/WikiMCP

set -e

# Colors for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 项目信息
REPO="qianshoutech/WikiMCP"
BINARY_NAME="wikimcp"

printf "${BLUE}╔══════════════════════════════════════════╗${NC}\n"
printf "${BLUE}║       正在安装 WikiMCP Server            ║${NC}\n"
printf "${BLUE}╚══════════════════════════════════════════╝${NC}\n"
printf "\n"

# 检测系统
OS=$(uname -s)

if [ "$OS" != "Darwin" ]; then
  printf "${RED}错误: WikiMCP 仅支持 macOS 系统。${NC}\n"
  exit 1
fi

printf "${BLUE}检测到系统: macOS${NC}\n"

# Create ~/.local/bin directory (if it doesn't exist)
if [ ! -d "$HOME/.local/bin" ]; then
  printf "${YELLOW}正在创建 ~/.local/bin 目录...${NC}\n"
  mkdir -p "$HOME/.local/bin"
fi

# Add to PATH based on the current shell (if not already added)
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  printf "${YELLOW}正在将 ~/.local/bin 添加到 PATH 环境变量...${NC}\n"
  
  # Detect the user's actual login shell
  USER_SHELL=$(basename "$SHELL")
  
  # Determine shell configuration file
  if [ -f "$HOME/.zshrc" ] && [[ "$USER_SHELL" == "zsh" ]]; then
    SHELL_CONFIG="$HOME/.zshrc"
    printf "${BLUE}检测到登录 Shell: ZSH${NC}\n"
  elif [ -f "$HOME/.bashrc" ] && [[ "$USER_SHELL" == "bash" ]]; then
    SHELL_CONFIG="$HOME/.bashrc"
    printf "${BLUE}检测到登录 Shell: Bash${NC}\n"
  elif [ -f "$HOME/.zshrc" ]; then
    SHELL_CONFIG="$HOME/.zshrc"
    printf "${BLUE}找到 .zshrc 配置文件${NC}\n"
  elif [ -f "$HOME/.bashrc" ]; then
    SHELL_CONFIG="$HOME/.bashrc"
    printf "${BLUE}找到 .bashrc 配置文件${NC}\n"
  else
    SHELL_CONFIG="$HOME/.profile"
    printf "${YELLOW}使用 ~/.profile 作为备选配置文件${NC}\n"
  fi
  
  if [ -f "$SHELL_CONFIG" ] || [ "$SHELL_CONFIG" = "$HOME/.profile" ]; then
    if [ ! -f "$SHELL_CONFIG" ]; then
      touch "$SHELL_CONFIG"
    fi
    # Check if already added
    if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$SHELL_CONFIG" 2>/dev/null; then
      echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_CONFIG"
      printf "${GREEN}已将 PATH 添加到 $SHELL_CONFIG${NC}\n"
    fi
    printf "${YELLOW}提示: 你可能需要重启终端或运行 'source $SHELL_CONFIG' 使 PATH 变更生效${NC}\n"
  else
    printf "${RED}警告: 找不到 shell 配置文件，请手动将 ~/.local/bin 添加到 PATH。${NC}\n"
  fi
fi

# Download and install the latest version
printf "\n"
printf "${BLUE}正在下载最新版本...${NC}\n"

# 构建下载 URL
DOWNLOAD_URL="https://github.com/${REPO}/releases/latest/download/${BINARY_NAME}.tar.gz"

if ! curl -fSL "$DOWNLOAD_URL" | tar xz -C "$HOME/.local/bin"; then
  printf "${RED}错误: 下载或解压二进制文件失败。${NC}\n"
  printf "${RED}URL: $DOWNLOAD_URL${NC}\n"
  printf "${YELLOW}请检查 Release 是否存在: https://github.com/${REPO}/releases${NC}\n"
  exit 1
fi

chmod +x "$HOME/.local/bin/$BINARY_NAME"

# Remove quarantine attribute (macOS security)
if command -v xattr >/dev/null 2>&1; then
  xattr -d com.apple.quarantine "$HOME/.local/bin/$BINARY_NAME" 2>/dev/null || true
fi

# Verify installation
if [ -x "$HOME/.local/bin/$BINARY_NAME" ]; then
  printf "\n"
  printf "${GREEN}╔══════════════════════════════════════════╗${NC}\n"
  printf "${GREEN}║         ✅ 安装完成！                    ║${NC}\n"
  printf "${GREEN}╚══════════════════════════════════════════╝${NC}\n"
  printf "\n"
  
  # Check if executable is in PATH
  if command -v "$BINARY_NAME" >/dev/null 2>&1; then
    printf "${GREEN}$BINARY_NAME 已在 PATH 中，可以直接使用。${NC}\n"
  else
    printf "${YELLOW}提示: $BINARY_NAME 已安装，但可能不在当前 PATH 中。${NC}\n"
    printf "${YELLOW}你可以运行以下命令立即使用:${NC}\n"
    printf "${BLUE}  ~/.local/bin/$BINARY_NAME${NC}\n"
    printf "${YELLOW}或者重启终端使 PATH 变更生效。${NC}\n"
  fi
  
  printf "\n"
  printf "${BLUE}═══════════════════════════════════════════${NC}\n"
  printf "${BLUE}  配置说明${NC}\n"
  printf "${BLUE}═══════════════════════════════════════════${NC}\n"
  printf "\n"
  printf "将以下内容添加到你的 MCP 客户端配置中:\n"
  printf "\n"
  printf "${GREEN}以 Cursor IDE 为例 (~/.cursor/mcp.json):${NC}\n"
  printf "\n"
  cat << 'EOF'
{
  "mcpServers": {
    "wikimcp": {
      "command": "~/.local/bin/wikimcp",
      "args": ["chrome"]
    }
  }
}
EOF
  printf "\n"
  printf "${YELLOW}args 参数说明: 指定从哪个浏览器读取 Cookie，默认为 chrome${NC}\n"
  printf "${YELLOW}支持的浏览器: safari, chrome, chromeBeta, chromeCanary, arc, edge, brave, firefox, vivaldi 等${NC}\n"
  printf "${YELLOW}提示: 其他支持 MCP 的客户端配置方式类似${NC}\n"
  printf "\n"
  printf "${BLUE}═══════════════════════════════════════════${NC}\n"
  printf "${BLUE}  首次使用权限配置${NC}\n"
  printf "${BLUE}═══════════════════════════════════════════${NC}\n"
  printf "\n"
  printf "${GREEN}Chromium 系浏览器 (Chrome、Edge、Arc、Brave 等):${NC}\n"
  printf "  首次运行时，系统会弹出钥匙串访问提示\n"
  printf "  请输入密码并选择「始终允许」以避免每次都弹出提示\n"
  printf "\n"
  printf "${GREEN}Safari 浏览器:${NC}\n"
  printf "  需要在系统设置中开启「完全磁盘访问权限」\n"
  printf "  1. 打开「系统设置」→「隐私与安全性」→「完全磁盘访问权限」\n"
  printf "  2. 添加并启用 Cursor 或你使用的终端应用\n"
  printf "\n"
  printf "${YELLOW}确保浏览器已登录 wiki.p1.cn，Cookie 将自动从浏览器读取${NC}\n"
  printf "\n"
else
  printf "${RED}错误: 安装失败，二进制文件不可执行。${NC}\n"
  exit 1
fi
