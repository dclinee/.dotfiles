#!/usr/bin/env bash

# ======================
# Python 环境体检
# ======================
#
# 功能:
#   1. 检查 python3 / uv / pip3 / pipx 版本
#   2. 验证镜像源配置
#   3. 检查虚拟环境状态
#   4. 检查 CLI 工具安装状态（tools.list）
#   5. 检查配置文件软链
#   6. 权限排查

set -euo pipefail

# shellcheck source=/dev/null
source "$(dirname "$0")/_common.sh"

PASS=0
WARN=0
FAIL=0

# 检查并统计
check_ok()   { echo_success "$1"; PASS=$((PASS + 1)); }
check_warn()  { echo_warning "$1"; WARN=$((WARN + 1)); }
check_fail()  { echo_error "$1"; FAIL=$((FAIL + 1)); }

# ======================
# 检查核心工具
# ======================
check_core_tools() {
  echo_step "核心工具"

  if has_python3; then
    check_ok "python3: $(python3 --version 2>&1)"
  else
    check_fail "python3: 未安装"
  fi

  if has_uv; then
    check_ok "uv: $(uv --version 2>&1)"
  else
    check_warn "uv: 未安装（建议安装以加速包管理）"
  fi

  if has_pip; then
    check_ok "pip3: $(pip3 --version 2>&1 | head -1)"
  else
    check_warn "pip3: 未安装"
  fi

  if has_pipx; then
    check_ok "pipx: $(pipx --version 2>&1 | head -1)"
  else
    check_warn "pipx: 未安装（uv 可替代）"
  fi
}

# ======================
# 检查镜像源配置
# ======================
check_mirror() {
  echo_step "镜像源配置"

  # uv 配置
  local uv_config="${HOME}/.config/uv/uv.toml"
  if [[ -f "$uv_config" ]]; then
    if grep -q 'index-url' "$uv_config" 2>/dev/null; then
      local mirror
      mirror="$(grep 'index-url' "$uv_config" | head -1 | sed 's/.*= *"\(.*\)".*/\1/')"
      check_ok "uv 镜像源: ${mirror}"
    else
      check_warn "uv 配置缺少 index-url"
    fi
  else
    check_warn "uv 配置不存在: ~/.config/uv/uv.toml"
  fi

  # pip 配置
  local pip_config="${HOME}/.pip/pip.conf"
  if [[ -f "$pip_config" ]]; then
    if grep -q 'index-url' "$pip_config" 2>/dev/null; then
      local mirror
      mirror="$(grep 'index-url' "$pip_config" | head -1 | sed 's/.*= *\(.*\)/\1/')"
      check_ok "pip 镜像源: ${mirror}"
    else
      check_warn "pip 配置缺少 index-url"
    fi
  else
    check_warn "pip 配置不存在: ~/.pip/pip.conf"
  fi
}

# ======================
# 检查虚拟环境
# ======================
check_venv() {
  echo_step "虚拟环境"

  local venv_dir="${HOME}/.venv-dotfiles"
  if [[ -d "$venv_dir" && -f "${venv_dir}/bin/python" ]]; then
    local py_ver
    py_ver="$("${venv_dir}/bin/python" --version 2>&1)"
    check_ok "venv 存在: ${venv_dir} (${py_ver})"

    # 检查关键依赖
    local key_pkgs=("pip" "setuptools" "wheel")
    for pkg in "${key_pkgs[@]}"; do
      if "${venv_dir}/bin/pip" show "$pkg" > /dev/null 2>&1; then
        check_ok "venv 已装: ${pkg}"
      else
        check_warn "venv 缺失: ${pkg}"
      fi
    done
  else
    check_warn "venv 不存在: ${venv_dir}"
    echo "  创建: make python-venv"
  fi

  # PATH 标记文件
  local marker="${HOME}/.local/share/dotfiles-py-path"
  if [[ -f "$marker" ]]; then
    check_ok "PATH 标记存在: ${marker}"
  else
    check_warn "PATH 标记缺失: ${marker}"
  fi
}

# ======================
# 检查配置文件软链
# ======================
check_configs() {
  echo_step "配置文件软链"

  local configs=(
    "${HOME}/.config/uv/uv.toml:${PYTHON_DIR}/uv.toml.template"
    "${HOME}/.pip/pip.conf:${PYTHON_DIR}/pip.conf"
    "${HOME}/.pythonrc.py:${PYTHON_DIR}/pythonrc.py"
    "${HOME}/.pyproject.toml:${PYTHON_DIR}/pyproject.toml.template"
  )

  for pair in "${configs[@]}"; do
    local dst="${pair%%:*}"
    local src="${pair##*:}"
    if [[ -L "$dst" ]]; then
      local target
      target="$(readlink "$dst" 2>/dev/null)"
      if [[ "$target" == "$src" ]]; then
        check_ok "软链正确: $(basename "$dst")"
      else
        check_warn "软链指向不同: $(basename "$dst") → ${target}"
      fi
    elif [[ -f "$dst" ]]; then
      check_warn "存在独立文件（非软链）: $(basename "$dst")"
    else
      check_fail "缺失: $(basename "$dst")"
    fi
  done
}

# ======================
# 检查 CLI 工具
# ======================
check_tools() {
  echo_step "CLI 工具（tools.list）"

  if ! has_uv && ! has_pipx; then
    check_warn "uv 和 pipx 均不可用，跳过"
    return 0
  fi

  if ! read_tools_list > /dev/null 2>&1; then
    check_warn "tools.list 不存在"
    return 0
  fi

  while read -r name version; do
    [[ -z "$name" ]] && continue
    if command -v "$name" > /dev/null 2>&1; then
      check_ok "已安装: ${name}"
    elif has_uv && uv tool list 2>/dev/null | grep -q "^${name}"; then
      check_ok "已安装（uv tool）: ${name}"
    elif has_pipx && pipx list 2>/dev/null | grep -q "package ${name}"; then
      check_ok "已安装（pipx）: ${name}"
    else
      check_warn "未安装: ${name}"
    fi
  done < <(read_tools_list)
}

# ======================
# 权限排查
# ======================
check_permissions() {
  echo_step "权限排查"

  local dirs=("${HOME}/.venv-dotfiles" "${HOME}/.local/share/uv" "${HOME}/.cache/uv")

  for d in "${dirs[@]}"; do
    if [[ -d "$d" ]]; then
      local owner
      owner="$(stat -c '%U' "$d" 2>/dev/null || stat -f '%Su' "$d" 2>/dev/null || echo '?')"
      if [[ "$owner" == "$(whoami)" ]]; then
        check_ok "$(basename "$d") 权限正常（owner: ${owner}）"
      else
        check_fail "$(basename "$d") 属主异常: ${owner}（应为 $(whoami)）"
      fi
    fi
  done

  # 检查 python3 路径
  if has_python3; then
    local py_path
    py_path="$(command -v python3)"
    if [[ "$py_path" == *"/linuxbrew/"* ]] || [[ "$py_path" == *"/homebrew/"* ]]; then
      check_warn "python3 路径: Homebrew 模式"
    elif [[ "$py_path" == /usr/bin/python3 ]]; then
      check_warn "python3 路径: 系统自带（建议使用 uv 管理版本）"
    else
      check_ok "python3 路径: ${py_path}"
    fi
  fi
}

# ======================
# 主流程
# ======================
main() {
  echo_title "Python 环境体检"

  check_core_tools
  echo_separator
  check_mirror
  echo_separator
  check_venv
  echo_separator
  check_configs
  echo_separator
  check_tools
  echo_separator
  check_permissions

  echo_title "体检结果"
  printf "${GREEN}✓ 通过: ${PASS}${RESET}  ${YELLOW}⚠ 警告: ${WARN}${RESET}  ${RED}✗ 失败: ${FAIL}${RESET}\n"

  if [[ $FAIL -gt 0 ]]; then
    echo ""
    echo_error "存在 ${FAIL} 项失败，建议修复"
    exit 1
  elif [[ $WARN -gt 0 ]]; then
    echo ""
    echo_warning "存在 ${WARN} 项警告，建议检查"
  else
    echo ""
    echo_success "所有检查项通过"
  fi
  echo_separator
}

main
