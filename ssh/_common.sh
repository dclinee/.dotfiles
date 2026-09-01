#!/usr/bin/env bash
# 本文件由调用者 source，预期调用者已设置 set -euo pipefail

# ======================
# SSH 模块公共加载器（内部文件）
# ======================
#
# 仅做路径解析 + 委托 lib/common.sh，具体函数见 lib/common.sh
# 使用方法: source "$(dirname "$0")/_common.sh"

SSH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "${SSH_DIR}/.." && pwd)}"

# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/common.sh" || {
  printf 'ERROR: 无法加载 lib/common.sh\n' >&2
  exit 1
}

# ======================
# SSH 专用快捷函数
# ======================
has_ssh() { has_cmd ssh; }

get_ssh_version() {
  has_ssh || return 1
  # ssh -V 输出到 stderr，需重定向合并
  ssh -V 2>&1 | head -1
}

# 读取文件权限位（跨平台: GNU stat -c 与 BSD/macOS stat -f）
# -L 跟随符号链接（BSD stat 默认返回软链自身权限，需显式跟随）
get_file_mode() {
  stat -L -c '%a' "$1" 2>/dev/null || stat -L -f '%Lp' "$1" 2>/dev/null || echo '?'
}
