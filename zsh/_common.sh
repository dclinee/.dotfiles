#!/usr/bin/env bash
# 本文件由调用者 source，预期调用者已设置 set -euo pipefail

# ======================
# Zsh 模块公共加载器（内部文件）
# ======================
#
# 仅做路径解析 + 委托 lib/common.sh，具体函数见 lib/common.sh
# 使用方法: source "$(dirname "$0")/_common.sh"

ZSH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "${ZSH_DIR}/.." && pwd)}"

# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/common.sh" || {
  printf 'ERROR: 无法加载 lib/common.sh\n' >&2
  exit 1
}

# ======================
# Zsh 专用快捷函数
# ======================
has_zsh() { has_cmd zsh; }

get_zsh_version() {
  has_zsh || return 1
  zsh --version 2>&1 | head -1
}
