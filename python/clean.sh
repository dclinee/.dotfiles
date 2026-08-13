#!/usr/bin/env bash

# ======================
# Python 缓存清理
# ======================
#
# 功能:
#   1. 清理 pip 缓存
#   2. 清理 uv 缓存
#   3. 清理 __pycache__ 目录
#   4. 移除过期的 CLI 工具（--deep）
#
# 用法:
#   ./clean.sh              # 标准清理（缓存 + __pycache__）
#   ./clean.sh --deep       # 深度清理（含卸载未在 tools.list 中的工具）
#   ./clean.sh --dry-run    # 预览将清理的内容（不实际执行）

set -euo pipefail

# shellcheck source=/dev/null
source "$(dirname "$0")/_common.sh"

DEEP=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --deep)    DEEP=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help)
      echo "用法: $(basename "$0") [--deep] [--dry-run]"
      echo "  --deep     深度清理（含卸载冗余工具）"
      echo "  --dry-run  预览将清理的内容（不实际执行）"
      exit 0 ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done

# ======================
# 清理 pip 缓存
# ======================
clean_pip_cache() {
  echo_step "清理 pip 缓存..."

  local pip_cache="${HOME}/.cache/pip"
  if [[ -d "$pip_cache" ]]; then
    local size
    size="$(du -sh "$pip_cache" 2>/dev/null | awk '{print $1}')"
    echo_detail "pip 缓存大小: ${size}"
    if is_dry_run; then
      echo_detail "[dry-run] rm -rf ${pip_cache}/*"
    else
      rm -rf "${pip_cache:?}"/* 2>/dev/null || true
    fi
    echo_success "已清理 pip 缓存"
  else
    echo_skip "pip 缓存目录不存在"
  fi
}

# ======================
# 清理 uv 缓存
# ======================
clean_uv_cache() {
  echo_step "清理 uv 缓存..."

  if ! has_uv; then
    echo_skip "uv 不可用"
    return 0
  fi

  local uv_cache="${HOME}/.cache/uv"
  if [[ -d "$uv_cache" ]]; then
    local size
    size="$(du -sh "$uv_cache" 2>/dev/null | awk '{print $1}')"
    echo_detail "uv 缓存大小: ${size}"
    if is_dry_run; then
      echo_detail "[dry-run] uv cache clean"
    else
      uv cache clean 2>/dev/null || rm -rf "${uv_cache:?}/"*
    fi
    echo_success "已清理 uv 缓存"
  else
    echo_skip "uv 缓存目录不存在"
  fi
}

# ======================
# 清理 __pycache__ 目录
# ======================
clean_pycache() {
  echo_step "清理 __pycache__ 目录..."

  if is_dry_run; then
    echo_detail "[dry-run] find ${HOME} -name __pycache__ -type d -prune -exec rm -rf {} +"
    return 0
  fi

  local count=0
  while IFS= read -r -d '' d; do
    rm -rf "$d" 2>/dev/null && count=$((count + 1))
  done < <(find "${HOME}/.dotfiles" -name __pycache__ -type d -prune -print0 2>/dev/null)

  if [[ $count -eq 0 ]]; then
    echo_skip "未发现 __pycache__ 目录"
  else
    echo_success "已清理 ${count} 个 __pycache__ 目录"
  fi
}

# ======================
# 移除冗余工具
# ======================
clean_redundant_tools() {
  if ! $DEEP; then
    return 0
  fi

  if ! has_uv && ! has_pipx; then
    return 0
  fi

  echo_step "检查冗余工具（深度模式）..."

  # 获取 tools.list 中的工具名
  local expected_tools=()
  if read_tools_list > /dev/null 2>&1; then
    while read -r name version; do
      [[ -n "$name" ]] && expected_tools+=("$name")
    done < <(read_tools_list)
  fi

  local removed=0

  # uv 工具列表
  if has_uv; then
    local installed_tools
    installed_tools="$(uv tool list 2>/dev/null | awk '{print $1}' | xargs)"
    for tool in $installed_tools; do
      [[ -z "$tool" ]] && continue
      local found=false
      for expected in "${expected_tools[@]}"; do
        [[ "$tool" == "$expected" ]] && found=true && break
      done

      if ! $found; then
        echo_detail "发现冗余工具: ${tool}"
        if is_dry_run; then
          echo_detail "[dry-run] uv tool uninstall ${tool}"
        else
          uv tool uninstall "$tool" 2>/dev/null && echo_success "已卸载: ${tool}" || true
        fi
        removed=$((removed + 1))
      fi
    done
  fi

  # pipx 工具列表
  if has_pipx; then
    local pipx_tools
    pipx_tools="$(pipx list --short 2>/dev/null | awk '{print $1}')"
    for tool in $pipx_tools; do
      [[ -z "$tool" ]] && continue
      local found=false
      for expected in "${expected_tools[@]}"; do
        [[ "$tool" == "$expected" ]] && found=true && break
      done

      if ! $found; then
        echo_detail "发现冗余工具（pipx）: ${tool}"
        if is_dry_run; then
          echo_detail "[dry-run] pipx uninstall ${tool}"
        else
          pipx uninstall "$tool" 2>/dev/null && echo_success "已卸载: ${tool}" || true
        fi
        removed=$((removed + 1))
      fi
    done
  fi

  [[ $removed -eq 0 ]] && echo_skip "未发现冗余工具"
}

# ======================
# 清理 venv 缓存
# ======================
clean_venv_cache() {
  echo_step "清理 venv 缓存..."

  local venv_dir="${HOME}/.venv-dotfiles"
  if [[ ! -d "$venv_dir" ]]; then
    echo_skip "venv 不存在"
    return 0
  fi

  # 清理 .pyc 文件
  if is_dry_run; then
    echo_detail "[dry-run] find ${venv_dir} -name '*.pyc' -delete"
    return 0
  fi

  local pyc_count
  pyc_count="$(find "$venv_dir" -name '*.pyc' -type f 2>/dev/null | wc -l)"
  if [[ $pyc_count -gt 0 ]]; then
    find "$venv_dir" -name '*.pyc' -type f -delete 2>/dev/null
    echo_success "已清理 ${pyc_count} 个 .pyc 文件"
  else
    echo_skip "venv 无 .pyc 文件"
  fi
}

# ======================
# 主流程
# ======================
main() {
  echo_title "Python 缓存清理"
  is_dry_run && echo_warning "DRY-RUN 模式：仅预览，不实际执行"
  echo ""

  clean_pip_cache
  echo_separator
  clean_uv_cache
  echo_separator
  clean_pycache
  echo_separator
  clean_venv_cache
  echo_separator
  clean_redundant_tools

  echo_title "清理完成"
  if ! is_dry_run; then
    echo_step "当前缓存目录大小:"
    du -sh "${HOME}/.cache/pip" 2>/dev/null || true
    du -sh "${HOME}/.cache/uv" 2>/dev/null || true
  fi
  echo_separator
}

main
