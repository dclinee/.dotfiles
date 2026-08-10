#!/usr/bin/env bash

# ======================
# Python 模块公共加载器（内部文件）
# ======================
#
# 仅做路径解析 + 委托 lib/common.sh，具体函数见 lib/common.sh
# 使用方法: source "$(dirname "$0")/_common.sh"

PYTHON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "${PYTHON_DIR}/.." && pwd)}"

# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/common.sh" || {
  echo "ERROR: 无法加载 lib/common.sh" >&2
  exit 1
}

# ======================
# Python 专用快捷函数（基于 has_cmd 封装，提高语义化）
# ======================
has_uv()      { has_cmd uv; }
has_python3() { has_cmd python3; }
has_pip()     { has_cmd pip3; }
has_pipx()    { has_cmd pipx; }

# 获取 Python 版本（短格式，如 3.11.5）
get_python_version() {
  has_python3 || return 1
  python3 --version 2>&1 | awk '{print $2}'
}

# 获取 venv 路径
get_venv_dir() {
  local venv="${HOME}/.venv-dotfiles"
  [[ -d "$venv" ]] && echo "$venv" || echo ""
}

# 判断 venv 是否已创建
has_venv() {
  [[ -d "${HOME}/.venv-dotfiles" && -f "${HOME}/.venv-dotfiles/bin/python" ]]
}
