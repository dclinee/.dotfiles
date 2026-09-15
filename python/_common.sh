#!/usr/bin/env bash
# python/_common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/_module_loader.sh" "PYTHON_DIR"

# Python 专用快捷函数
has_uv()      { has_cmd uv; }
has_python3() { has_cmd python3; }
has_pip()     { has_cmd pip3; }
has_pipx()    { has_cmd pipx; }

get_python_version() {
  has_python3 || return 1
  python3 --version 2>&1 | awk '{print $2}'
}

get_venv_dir() {
  local venv="${HOME}/.venv-dotfiles"
  [[ -d "$venv" ]] && echo "$venv" || echo ""
}

has_venv() {
  [[ -d "${HOME}/.venv-dotfiles" && -f "${HOME}/.venv-dotfiles/bin/python" ]]
}
