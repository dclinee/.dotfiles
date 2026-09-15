#!/usr/bin/env bash
# tmux/check.sh — Tmux 环境体检
set -euo pipefail
source "$(dirname "$0")/_common.sh"

check_init

if has_tmux; then
  check_ok "tmux: $(tmux -V)"
else
  check_fail "tmux: 未安装"
fi

if [[ -L "${HOME}/.tmux.conf" ]]; then
  check_ok ".tmux.conf 软链存在"
else
  check_warn ".tmux.conf 软链不存在"
fi

check_summary
