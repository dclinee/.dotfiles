#!/usr/bin/env bash
# brew/check.sh — Homebrew 环境体检
set -euo pipefail
source "$(dirname "$0")/_common.sh"

check_init

if has_brew; then
  check_ok "brew: $(brew --version | head -1)"
else
  check_fail "brew: 未安装"
fi

if [[ -f "${BREW_DIR}/Brewfile" ]]; then
  check_ok "Brewfile 存在"
else
  check_warn "Brewfile 不存在"
fi

check_summary
