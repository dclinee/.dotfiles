#!/usr/bin/env bash

# ======================
# SSH 配置卸载器
# ======================
#
# 功能:
#   1. 移除 ~/.ssh/config 软链
#   2. 密钥与本机私有配置（config.local）不删除
#
# 用法:
#   ./uninstall.sh             # 仅移除配置软链
#   ./uninstall.sh --dry-run   # 预览操作

set -euo pipefail

# shellcheck source=/dev/null
source "$(dirname "$0")/_common.sh"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) export DRY_RUN=true; shift ;;
    -h|--help)
      printf '用法: %s [--dry-run]\n' "$(basename "$0")"
      printf '%s\n' "  --dry-run 预览操作，不实际执行"
      exit 0 ;;
    *) printf '未知参数: %s\n' "$1"; exit 1 ;;
  esac
done

# ======================
# 移除配置软链
# ======================
remove_symlinks_local() {
  echo_step "移除 SSH 配置软链..."

  local configs=(
    "${HOME}/.ssh/config|${SSH_DIR}/config"
  )

  remove_symlinks "${configs[@]}"
}

# ======================
# 主流程
# ======================
main() {
  echo_title "SSH 配置卸载器"
  is_dry_run && echo_warning "DRY-RUN 模式：仅预览，不实际执行"

  remove_symlinks_local

  echo_title "卸载完成"
  if ! is_dry_run; then
    echo_success "SSH 配置软链已移除"
    echo_detail "密钥与 ~/.ssh/config.local 均保留，如需一并清理请手动删除"
  fi
}

main
