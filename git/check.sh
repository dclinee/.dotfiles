#!/usr/bin/env bash
# git/check.sh — Git 环境体检
set -euo pipefail
source "$(dirname "$0")/_common.sh"

check_init

if has_git; then
  check_ok "git: $(git --version)"
else
  check_fail "git: 未安装"
fi

if [[ -L "${HOME}/.gitconfig" ]]; then
  check_ok ".gitconfig 软链存在"
else
  check_warn ".gitconfig 软链不存在"
fi

if git config --global user.name > /dev/null 2>&1; then
  check_ok "user.name: $(git config --global user.name)"
else
  check_warn "user.name 未配置（请编辑 ~/.gitconfig.local）"
fi

check_summary
