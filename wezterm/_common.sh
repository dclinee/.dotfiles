#!/usr/bin/env bash
# 本文件由调用者 source，预期调用者已设置 set -euo pipefail

# ======================
# Wezterm 模块公共加载器（内部文件）
# ======================
#
# 仅做路径解析 + 委托 lib/common.sh，具体函数见 lib/common.sh
# 使用方法: source "$(dirname "$0")/_common.sh"

WEZTERM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "${WEZTERM_DIR}/.." && pwd)}"

# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/common.sh" || {
  echo "ERROR: 无法加载 lib/common.sh" >&2
  exit 1
}

# ======================
# Wezterm 专用快捷函数
# ======================
has_wezterm() { has_cmd wezterm; }

get_wezterm_version() {
  has_wezterm || return 1
  wezterm --version 2>&1 | head -1
}
