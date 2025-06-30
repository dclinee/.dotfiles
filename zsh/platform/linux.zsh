#!/usr/bin/env zsh

# ======================
# Linux 专用配置
# ======================

# Linuxbrew 路径
if [[ -d "${HOME}/.linuxbrew" ]]; then
  eval "$(${HOME}/.linuxbrew/bin/brew shellenv)"
fi

# 包管理器别名
if command -v apt > /dev/null; then
  alias update='sudo apt update && sudo apt upgrade'
elif command -v dnf > /dev/null; then
  alias update='sudo dnf upgrade'
elif command -v pacman > /dev/null; then
  alias update='sudo pacman -Syu'
fi

# X11 转发支持
if [[ -n "$SSH_CLIENT" ]]; then
  export DISPLAY="${SSH_CLIENT%% *}:0"
fi

# 系统监控别名
alias meminfo='free -mlt'
alias cpuinfo='lscpu'
alias diskusage='df -h'
