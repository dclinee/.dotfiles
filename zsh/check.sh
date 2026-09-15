#!/usr/bin/env bash
# zsh/check.sh — Zsh 环境体检
set -euo pipefail
source "$(dirname "$0")/_common.sh"

check_init

if has_zsh; then
  check_ok "zsh: $(zsh --version)"
else
  check_fail "zsh: 未安装"
fi

if [[ -L "${HOME}/.zshrc" ]]; then
  check_ok ".zshrc 软链存在"
else
  check_warn ".zshrc 软链不存在"
fi

if [[ -d "${ZSH_DIR}/core" ]]; then
  check_ok "core/ 目录存在"
fi

check_summary
