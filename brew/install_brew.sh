#!/bin/bash
set -eo pipefail

# 使用 USTC 镜像安装 Homebrew (macOS/Linux) - 修正版
# 来源：https://mirrors.ustc.edu.cn/help/brew.git.html

# 设置环境变量
export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.ustc.edu.cn/brew.git"
export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.ustc.edu.cn/homebrew-core.git"
export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles"

# 安全下载并执行脚本（替代 curl | bash）
_download_and_run() {
  local url="$1"
  local tmp_file
  tmp_file="$(mktemp)"
  trap 'rm -f "${tmp_file}"' EXIT RETURN

  echo "下载脚本: ${url}"
  if ! curl -fsSL "${url}" -o "${tmp_file}"; then
    echo "错误: 下载失败 ${url}"
    return 1
  fi

  echo "执行下载的安装脚本..."
  bash "${tmp_file}"
  local rc=$?
  rm -f "${tmp_file}"
  return $rc
}

# 自动判断系统类型
if [[ "$(uname)" == "Darwin" ]]; then
    echo "开始安装 Homebrew (macOS)..."
    _download_and_run "https://mirrors.ustc.edu.cn/misc/brew-install.sh"
elif [[ "$(uname)" == "Linux" ]]; then
    echo "开始安装 Homebrew (Linux)..."
    _download_and_run "https://mirrors.ustc.edu.cn/misc/brew-install.sh"
else
    echo "错误：不支持的操作系统"
    exit 1
fi

# 配置镜像源
echo "正在配置 USTC 镜像源..."
if [[ "$(uname)" == "Linux" ]] && [[ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" 2>/dev/null || true
elif [[ "$(uname)" == "Darwin" ]] && [[ -x "/opt/homebrew/bin/brew" ]]; then
    # Apple Silicon (M1/M2/M3)
    eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true
elif [[ "$(uname)" == "Darwin" ]] && [[ -x "/usr/local/bin/brew" ]]; then
    # Intel Mac
    eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null || true
elif command -v brew > /dev/null 2>&1; then
    eval "$(brew shellenv)" 2>/dev/null || true
fi

brew update

printf '\n✅ Homebrew 安装完成！\n'
echo "已配置以下镜像源："
echo "  brew.git:       $HOMEBREW_BREW_GIT_REMOTE"
echo "  homebrew-core:  $HOMEBREW_CORE_GIT_REMOTE"
echo "  Bottles:        $HOMEBREW_BOTTLE_DOMAIN"
echo ""
echo "请将以下内容添加到你的 shell 配置文件中以持久化："
echo '  eval "$(brew shellenv)"'
