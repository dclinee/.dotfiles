#!/usr/bin/env bash

# ===================================
# Wezterm 跨平台配置链接脚本
# 支持 Linux/macOS/Windows (WSL)
# ===================================

set -e

echo "=== Wezterm 配置链接设置工具 ==="

echo "检测当前平台..."

# 平台检测
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "当前平台: Linux"
    
    # Linux 软连接创建
    echo "创建软连接: ~/.wezterm.lua -> ~/.dotfiles/wezterm/wezterm.lua"
    ln -sf "$HOME/.dotfiles/wezterm/wezterm.lua" "$HOME/.wezterm.lua"
    
    # 验证
    echo "验证软连接..."
    ls -la "$HOME/.wezterm.lua"
    
    echo "✅ Linux 软连接创建成功!"
    
elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "当前平台: macOS"
    
    # macOS 软连接创建
    echo "创建软连接: ~/.wezterm.lua -> ~/.dotfiles/wezterm/wezterm.lua"
    ln -sf "$HOME/.dotfiles/wezterm/wezterm.lua" "$HOME/.wezterm.lua"
    
    # 验证
    echo "验证软连接..."
    ls -la "$HOME/.wezterm.lua"
    
    echo "✅ macOS 软连接创建成功!"
    
elif [[ "$OSTYPE" == "cygwin"* || "$OSTYPE" == "msys"* || "$OSTYPE" == "win32"* ]]; then
    echo "当前平台: Windows (Git Bash/Cygwin/msys)"
    echo "请使用 PowerShell 执行以下命令:"
    echo ""
    echo "New-Item -ItemType SymbolicLink -Path \$env:USERPROFILE\.wezterm.lua -Target \$env:USERPROFILE\.dotfiles\wezterm\wezterm.lua -Force"
    echo ""
    echo "或者使用管理员权限运行:"
    echo "mklink \%USERPROFILE\%.wezterm.lua \%USERPROFILE\%.dotfiles\wezterm\wezterm.lua"
    
elif grep -qi microsoft /proc/version; then
    echo "当前平台: Windows WSL"
    
    # WSL 软连接创建 (同时创建 Windows 端链接)
    echo "创建 WSL 软连接..."
    ln -sf "$HOME/.dotfiles/wezterm/wezterm.lua" "$HOME/.wezterm.lua"
    
    # 验证
    echo "验证 WSL 软连接..."
    ls -la "$HOME/.wezterm.lua"
    
    echo ""
    echo "请在 Windows PowerShell 中创建 Windows 端链接:"
    echo "New-Item -ItemType SymbolicLink -Path \$env:USERPROFILE\.wezterm.lua -Target \wsl$\Ubuntu\home\$(whoami)\.dotfiles\wezterm\wezterm.lua -Force"
    
    echo "✅ WSL 软连接创建成功!"
    
else
    echo "❌ 不支持的平台: $OSTYPE"
    echo "请手动创建软连接:"
    echo "  目标: ~/.wezterm.lua"
    echo "  源文件: ~/.dotfiles/wezterm/wezterm.lua"
    exit 1
fi

echo ""
echo "=== 配置链接设置完成 ==="
echo "可以通过以下命令启动 Wezterm:"
echo "  wezterm"
echo ""
echo "配置文件位置: ~/.dotfiles/wezterm/wezterm.lua"
echo "详细文档: ~/.dotfiles/wezterm/README.md"
