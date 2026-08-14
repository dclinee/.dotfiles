#!/usr/bin/env zsh

# ======================
# Linux 专用配置
# ======================

# 包管理器别名
if command -v apt > /dev/null; then
  alias update='sudo apt update && sudo apt upgrade'
elif command -v dnf > /dev/null; then
  alias update='sudo dnf upgrade'
elif command -v pacman > /dev/null; then
  alias update='sudo pacman -Syu'
fi

# X11 转发支持
# 注: SSH X11 转发时 sshd 会自动设置 DISPLAY（如 localhost:10.0）
# 此处仅在 DISPLAY 未设置且 SSH_CLIENT 存在时作为 fallback
if [[ -z "${DISPLAY:-}" ]] && [[ -n "${SSH_CLIENT:-}" ]]; then
  export DISPLAY="localhost:10.0"
fi

# 系统监控别名
alias meminfo='free -mlt'
alias cpuinfo='lscpu'
alias diskusage='df -h'
