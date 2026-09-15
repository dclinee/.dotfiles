#!/usr/bin/env bash
# vim/check.sh — Vim 环境体检
set -euo pipefail
source "$(dirname "$0")/_common.sh"

check_init

if has_vim; then
  check_ok "vim: $(vim --version | head -1)"
else
  check_fail "vim: 未安装"
fi

if [[ -L "${HOME}/.vimrc" ]]; then
  check_ok ".vimrc 软链存在"
else
  check_warn ".vimrc 软链不存在"
fi

check_summary
