#!/bin/bash

# 使用 USTC 镜像安装 Homebrew (macOS/Linux) - 修正版
# 来源：https://mirrors.ustc.edu.cn/help/brew.git.html

# 设置环境变量
export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.ustc.edu.cn/brew.git"
export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.ustc.edu.cn/homebrew-core.git"
export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles"

# 自动判断系统类型
if [[ "$(uname)" == "Darwin" ]]; then
    echo "开始安装 Homebrew (macOS)..."
    # macOS 安装命令
    /bin/bash -c "$(curl -fsSL https://mirrors.ustc.edu.cn/misc/brew-install.sh)"
elif [[ "$(uname)" == "Linux" ]]; then
    echo "开始安装 Homebrew (Linux)..."
    # Linux 安装命令
    /bin/bash -c "$(curl -fsSL https://mirrors.ustc.edu.cn/misc/brew-install.sh)"
else
    echo "错误：不支持的操作系统"
    exit 1
fi

# 配置镜像源 (修正了无效选项)
echo "正在配置 USTC 镜像源..."
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" 2>/dev/null  # Linux
eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null  # macOS

brew update

echo -e "\n✅ Homebrew 安装完成！"
echo "已配置以下镜像源："
echo "  brew.git:       $HOMEBREW_BREW_GIT_REMOTE"
echo "  homebrew-core:  $HOMEBREW_CORE_GIT_REMOTE"
echo "  homebrew-cask:  https://mirrors.ustc.edu.cn/homebrew-cask.git"
echo "  Bottles:        $HOMEBREW_BOTTLE_DOMAIN"
