#!/usr/bin/env bash

# ======================
# Wezterm 配置卸载器
# ======================
#
# 功能:
#   1. 移除 .wezterm.lua 软链
#   2. 可选: 卸载 wezterm 本体（--purge，需确认）
#
# 用法:
#   ./uninstall.sh             # 仅移除配置软链
#   ./uninstall.sh --purge     # 彻底卸载（含本体，需确认）
#   ./uninstall.sh --dry-run   # 预览操作

set -euo pipefail

# shellcheck source=/dev/null
source "$(dirname "$0")/_common.sh"

PURGE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --purge) PURGE=true; shift ;;
    --dry-run) export DRY_RUN=true; shift ;;
    -h|--help)
      printf '用法: %s [--purge] [--dry-run]\n' "$(basename "$0")"
      printf '%s\n' "  --purge   彻底卸载（含 wezterm 本体，需确认）"
      printf '%s\n' "  --dry-run 预览操作，不实际执行"
      exit 0 ;;
    *) printf '未知参数: %s\n' "$1"; exit 1 ;;
  esac
done

# ======================
# 移除配置软链
# ======================
remove_symlinks_local() {
  echo_step "移除 Wezterm 配置软链..."

  local configs=(
    "${HOME}/.wezterm.lua|${WEZTERM_DIR}/wezterm.lua"
  )

  remove_symlinks "${configs[@]}"
}

# ======================
# 卸载 wezterm 本体
# ======================
purge_wezterm() {
  if ! $PURGE; then
    return 0
  fi

  echo_step "卸载 wezterm 本体..."

  if ! has_wezterm; then
    echo_skip "wezterm 未安装，跳过"
    return 0
  fi

  if is_dry_run; then
    echo_detail "[dry-run] 将执行对应包管理器卸载 wezterm"
    return 0
  fi

  local uname_s
  uname_s="$(uname -s | tr '[:upper:]' '[:lower:]')"

  case "$uname_s" in
    linux)
      if command -v apt > /dev/null; then
        echo_warning "请手动执行: sudo apt remove wezterm"
      elif command -v dnf > /dev/null; then
        echo_warning "请手动执行: sudo dnf remove wezterm"
      else
        echo_warning "无法确定包管理器，请手动卸载"
      fi
      ;;
    darwin)
      if command -v brew > /dev/null; then
        echo_warning "请手动执行: brew uninstall --cask wezterm"
      else
        echo_warning "请手动卸载 Wezterm.app"
      fi
      ;;
    *)
      echo_warning "未知平台，请手动卸载 wezterm"
      ;;
  esac
}

# ======================
# 主流程
# ======================
main() {
  echo_title "Wezterm 配置卸载器"
  is_dry_run && echo_warning "DRY-RUN 模式：仅预览，不实际执行"

  remove_symlinks_local
  purge_wezterm

  echo_title "卸载完成"
  if ! is_dry_run; then
    echo_success "Wezterm 配置已移除"
    if ! $PURGE; then
      echo_detail "wezterm 本体仍保留，如需卸载请使用 --purge"
    fi
  fi
}

main
