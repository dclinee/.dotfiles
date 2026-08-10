#!/usr/bin/env bash

# ======================
# Rust 缓存清理
# ======================
#
# 功能:
#   1. 清理 cargo 编译缓存（target/ 目录）
#   2. 清理 cargo registry 缓存
#   3. 移除过期的 cargo 工具
#   4. 清理 rustup 临时文件
#
# 用法:
#   ./clean.sh              # 标准清理（缓存 + registry）
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

# 执行或预览
run_cmd() {
  if $DRY_RUN; then
    echo "  [dry-run] $*"
  else
    eval "$@" 2>/dev/null || true
  fi
}

# ======================
# 清理 cargo 编译缓存
# ======================
clean_cargo_cache() {
  echo_step "清理 cargo 编译缓存..."

  if ! has_cargo; then
    echo_warning "cargo 不可用，跳过"
    return 0
  fi

  local cargo_cache="${HOME}/.cargo/registry/cache"
  local cargo_src="${HOME}/.cargo/registry/src"

  if [[ -d "$cargo_cache" ]]; then
    local size
    size="$(du -sh "$cargo_cache" 2>/dev/null | awk '{print $1}')"
    echo_detail "registry/cache 大小: ${size}"
    run_cmd "rm -rf ${cargo_cache}/*"
    echo_success "已清理 registry/cache"
  else
    echo_skip "registry/cache 不存在"
  fi

  if [[ -d "$cargo_src" ]]; then
    local size
    size="$(du -sh "$cargo_src" 2>/dev/null | awk '{print $1}')"
    echo_detail "registry/src 大小: ${size}"
    run_cmd "rm -rf ${cargo_src}/*"
    echo_success "已清理 registry/src"
  else
    echo_skip "registry/src 不存在"
  fi
}

# ======================
# 清理 cargo 全局缓存
# ======================
clean_cargo_global() {
  echo_step "清理 cargo 全局缓存..."

  if ! has_cargo; then
    return 0
  fi

  if $DRY_RUN; then
    echo "  [dry-run] cargo cache clean"
  else
    cargo cache -a 2>/dev/null || cargo cache --autoclean 2>/dev/null || {
      echo_skip "cargo-cache 未安装，跳过高级清理"
    }
  fi
}

# ======================
# 移除冗余工具
# ======================
clean_redundant_tools() {
  if ! $DEEP; then
    return 0
  fi

  if ! has_cargo; then
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

  # 获取已安装的 cargo 工具
  local installed_tools
  installed_tools="$(cargo install --list 2>/dev/null | grep '^[a-z]' | awk '{print $1}')"

  local removed=0
  for tool in $installed_tools; do
    local found=false
    for expected in "${expected_tools[@]}"; do
      [[ "$tool" == "$expected" ]] && found=true && break
    done

    if ! $found; then
      echo_detail "发现冗余工具: ${tool}"
      if $DRY_RUN; then
        echo "  [dry-run] cargo uninstall ${tool}"
      else
        cargo uninstall "$tool" 2>/dev/null && echo_success "已卸载: ${tool}" || true
      fi
      removed=$((removed + 1))
    fi
  done

  [[ $removed -eq 0 ]] && echo_skip "未发现冗余工具"
}

# ======================
# 清理 rustup 临时文件
# ======================
clean_rustup_temp() {
  echo_step "清理 rustup 临时文件..."

  if ! has_rustup; then
    echo_skip "rustup 不可用"
    return 0
  fi

  # 清理下载临时文件
  local rustup_tmp="${HOME}/.rustup/tmp"
  if [[ -d "$rustup_tmp" ]]; then
    local size
    size="$(du -sh "$rustup_tmp" 2>/dev/null | awk '{print $1}')"
    echo_detail "tmp 大小: ${size}"
    run_cmd "rm -rf ${rustup_tmp}/*"
    echo_success "已清理 rustup/tmp"
  else
    echo_skip "rustup/tmp 不存在"
  fi
}

# ======================
# 主流程
# ======================
main() {
  echo_title "Rust 缓存清理"
  $DRY_RUN && echo_warning "DRY-RUN 模式：仅预览，不实际执行"
  echo ""

  clean_cargo_cache
  echo_separator
  clean_cargo_global
  echo_separator
  clean_redundant_tools
  echo_separator
  clean_rustup_temp

  echo_title "清理完成"
  if ! $DRY_RUN && has_cargo; then
    echo_step "当前 cargo 目录大小:"
    du -sh "${HOME}/.cargo" 2>/dev/null || true
  fi
  echo_separator
}

main
