#!/usr/bin/env bash
# 本文件由调用者 source，预期调用者已设置 set -euo pipefail

# ======================
# Vim 模块公共加载器（内部文件）
# ======================
#
# 仅做路径解析 + 委托 lib/common.sh，具体函数见 lib/common.sh
# 使用方法: source "$(dirname "$0")/_common.sh"

VIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "${VIM_DIR}/.." && pwd)}"

# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/common.sh" || {
  printf 'ERROR: 无法加载 lib/common.sh\n' >&2
  exit 1
}

# ======================
# Vim 专用快捷函数
# ======================
has_vim() { has_cmd vim; }

get_vim_version() {
  has_vim || return 1
  vim --version 2>&1 | head -1
}

# 检测 sudo 可用性（用于包安装）
have_sudo() {
  if [[ $EUID -eq 0 ]]; then
    return 0
  fi
  sudo -n true 2>/dev/null
}
