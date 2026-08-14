#!/usr/bin/env bash
set -euo pipefail

# 使用 USTC 镜像安装 Homebrew (macOS/Linux) - 修正版
# 来源：https://mirrors.ustc.edu.cn/help/brew.git.html

# 设置环境变量
if [[ -z "${NO_MIRROR:-}" ]]; then
  export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.ustc.edu.cn/brew.git"
  export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.ustc.edu.cn/homebrew-core.git"
  export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles"
  export HOMEBREW_API_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles/api"
fi

# 安全下载并执行脚本（替代 curl | bash）
_download_and_run() {
  local url="$1"
  local tmp_file
  tmp_file="$(mktemp)"
  trap 'rm -f "${tmp_file}"' EXIT RETURN

  printf '下载脚本: %s\n' "${url}"
  if ! curl --proto '=https' --tlsv1.2 -fsSL --connect-timeout 15 --max-time 120 "${url}" -o "${tmp_file}"; then
    printf '错误: 下载失败 %s\n' "${url}"
    return 1
  fi

  # 安全检查: 文件非空且以 shebang 开头
  if [[ ! -s "${tmp_file}" ]]; then
    printf '错误: 下载的脚本为空\n'
    return 1
  fi
  local first_line
  first_line="$(head -1 "${tmp_file}")"
  if [[ ! "${first_line}" =~ ^#! ]]; then
    printf '错误: 下载的文件不是 shell 脚本（首行: %s）\n' "${first_line}"
    return 1
  fi

  printf '执行下载的安装脚本...\n'
  bash "${tmp_file}" || return $?
  rm -f "${tmp_file}"
  return 0
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
printf '已配置以下镜像源：\n'
printf '  brew.git:       %s\n' "${HOMEBREW_BREW_GIT_REMOTE:-}"
printf '  homebrew-core:  %s\n' "${HOMEBREW_CORE_GIT_REMOTE:-}"
printf '  Bottles:        %s\n' "${HOMEBREW_BOTTLE_DOMAIN:-}"
printf '  API:            %s\n' "${HOMEBREW_API_DOMAIN:-}"
printf '\n'
printf '请将以下内容添加到你的 shell 配置文件中以持久化：\n'
printf '  eval "$(brew shellenv)"\n'
