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

echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       Installing WikiMCP Server          ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo ""

# 检测系统
OS=$(uname -s)

if [ "$OS" != "Darwin" ]; then
  echo -e "${RED}Error: WikiMCP only supports macOS.${NC}"
  exit 1
fi

echo -e "${BLUE}Detected: macOS${NC}"

# Create ~/.local/bin directory (if it doesn't exist)
if [ ! -d "$HOME/.local/bin" ]; then
  echo -e "${YELLOW}Creating ~/.local/bin directory...${NC}"
  mkdir -p "$HOME/.local/bin"
fi

# Add to PATH based on the current shell (if not already added)
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  echo -e "${YELLOW}Adding ~/.local/bin to your PATH...${NC}"
  
  # Detect the user's actual login shell
  USER_SHELL=$(basename "$SHELL")
  
  # Determine shell configuration file
  if [ -f "$HOME/.zshrc" ] && [[ "$USER_SHELL" == "zsh" ]]; then
    SHELL_CONFIG="$HOME/.zshrc"
    echo -e "${BLUE}Detected ZSH as your login shell${NC}"
  elif [ -f "$HOME/.bashrc" ] && [[ "$USER_SHELL" == "bash" ]]; then
    SHELL_CONFIG="$HOME/.bashrc"
    echo -e "${BLUE}Detected Bash as your login shell${NC}"
  elif [ -f "$HOME/.zshrc" ]; then
    SHELL_CONFIG="$HOME/.zshrc"
    echo -e "${BLUE}Found .zshrc configuration file${NC}"
  elif [ -f "$HOME/.bashrc" ]; then
    SHELL_CONFIG="$HOME/.bashrc"
    echo -e "${BLUE}Found .bashrc configuration file${NC}"
  else
    SHELL_CONFIG="$HOME/.profile"
    echo -e "${YELLOW}Using ~/.profile as fallback${NC}"
  fi
  
  if [ -f "$SHELL_CONFIG" ] || [ "$SHELL_CONFIG" = "$HOME/.profile" ]; then
    if [ ! -f "$SHELL_CONFIG" ]; then
      touch "$SHELL_CONFIG"
    fi
    # Check if already added
    if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$SHELL_CONFIG" 2>/dev/null; then
      echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_CONFIG"
      echo -e "${GREEN}Added PATH to $SHELL_CONFIG${NC}"
    fi
    echo -e "${YELLOW}Note: You may need to restart your terminal or run 'source $SHELL_CONFIG' for PATH changes to take effect${NC}"
  else
    echo -e "${RED}Warning: Could not find shell configuration file. Please add ~/.local/bin to your PATH manually.${NC}"
  fi
fi

# Download and install the latest version
echo ""
echo -e "${BLUE}Downloading the latest version...${NC}"

# 构建下载 URL
DOWNLOAD_URL="https://github.com/${REPO}/releases/latest/download/${BINARY_NAME}.tar.gz"

if ! curl -fSL "$DOWNLOAD_URL" | tar xz -C "$HOME/.local/bin"; then
  echo -e "${RED}Error: Failed to download or extract the binary.${NC}"
  echo -e "${RED}URL: $DOWNLOAD_URL${NC}"
  echo -e "${YELLOW}Please check if the release exists at: https://github.com/${REPO}/releases${NC}"
  exit 1
fi

chmod +x "$HOME/.local/bin/$BINARY_NAME"

# Remove quarantine attribute (macOS security)
if command -v xattr >/dev/null 2>&1; then
  xattr -d com.apple.quarantine "$HOME/.local/bin/$BINARY_NAME" 2>/dev/null || true
fi

# Verify installation
if [ -x "$HOME/.local/bin/$BINARY_NAME" ]; then
  echo ""
  echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║    ✅ Installation completed!            ║${NC}"
  echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
  echo ""
  
  # Check if executable is in PATH
  if command -v "$BINARY_NAME" >/dev/null 2>&1; then
    echo -e "${GREEN}$BINARY_NAME is in your PATH and ready to use.${NC}"
  else
    echo -e "${YELLOW}Note: $BINARY_NAME is installed but may not be in your current PATH.${NC}"
    echo -e "${YELLOW}Run the following command to use it immediately:${NC}"
    echo -e "${BLUE}  $HOME/.local/bin/$BINARY_NAME${NC}"
    echo -e "${YELLOW}Or restart your terminal session for PATH changes to take effect.${NC}"
  fi
  
  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════${NC}"
  echo -e "${BLUE}  Configuration Instructions${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════${NC}"
  echo ""
  echo -e "Add the following to your MCP client configuration:"
  echo ""
  echo -e "${GREEN}For Cursor IDE (~/.cursor/mcp.json):${NC}"
  echo ""
  cat << 'EOF'
{
  "mcpServers": {
    "wikimcp": {
      "command": "$HOME/.local/bin/wikimcp",
      "env": {
        "WIKI_COOKIE": "your_cookie_string_here"
      }
    }
  }
}
EOF
  echo ""
  echo -e "${YELLOW}Note: Replace \$HOME with your actual home directory path${NC}"
  echo -e "${YELLOW}      e.g., /Users/yourusername/.local/bin/wikimcp${NC}"
  echo ""
  echo -e "To get your Wiki cookie:"
  echo -e "  1. Open https://wiki.p1.cn in browser and login"
  echo -e "  2. Open DevTools (F12) → Network tab"
  echo -e "  3. Refresh page, click any request"
  echo -e "  4. Copy the Cookie header value"
  echo ""
else
  echo -e "${RED}Error: Installation failed. The binary is not executable.${NC}"
  exit 1
fi

