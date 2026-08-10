#!/usr/bin/env bash

# ======================
# Wezterm 环境体检
# ======================
#
# 功能:
#   1. 检查 wezterm 是否安装
#   2. 验证配置软链
#   3. 检查 Lua 配置语法
#   4. 检查平台配置文件存在性
#   5. 权限排查

set -euo pipefail

# shellcheck source=/dev/null
source "$(dirname "$0")/_common.sh"

# 初始化体检计数器
check_init

# ======================
# 检查核心工具
# ======================
check_core_tools() {
  echo_step "核心工具"

  if has_wezterm; then
    check_ok "wezterm: $(get_wezterm_version)"
  else
    check_skip "wezterm: 未安装（配置已就绪，可按需安装）"
  fi
}

# ======================
# 检查配置软链
# ======================
check_configs() {
  echo_step "配置文件软链"

  local configs=(
    "${HOME}/.wezterm.lua|${WEZTERM_DIR}/wezterm.lua"
  )

  check_symlinks "${configs[@]}"
}

# ======================
# 检查配置文件语法
# ======================
check_syntax() {
  echo_step "配置文件语法"

  local wezterm_files=(
    "${WEZTERM_DIR}/wezterm.lua"
    "${WEZTERM_DIR}/core"/*.lua
    "${WEZTERM_DIR}/platform"/*.lua
  )

  local all_valid=true
  for file in "${wezterm_files[@]}"; do
    if [[ -f "${file}" ]]; then
      if command -v luac > /dev/null 2>&1; then
        if luac -p "${file}" 2>/dev/null; then
          check_ok "语法通过: $(basename "$file")"
        else
          check_fail "语法错误: $(basename "$file")"
          all_valid=false
        fi
      else
        check_ok "跳过$(basename "$file"): luac 不可用"
      fi
    fi
  done

  if ! $all_valid; then
    echo_warning "存在 Lua 语法错误，请检查日志"
  fi
}

# ======================
# 检查平台配置
# ======================
check_platform_config() {
  echo_step "平台配置"

  local uname_s
  uname_s="$(uname -s | tr '[:upper:]' '[:lower:]')"

  local platform_file=""
  case "$uname_s" in
    linux)   platform_file="${WEZTERM_DIR}/platform/linux.lua" ;;
    darwin)  platform_file="${WEZTERM_DIR}/platform/macos.lua" ;;
    windows) platform_file="${WEZTERM_DIR}/platform/windows.lua" ;;
    *)       check_warn "未知平台: $uname_s，跳过平台配置检查"; return 0 ;;
  esac

  if [[ -f "$platform_file" ]]; then
    check_ok "平台配置存在: $(basename "$platform_file")"
  else
    check_warn "平台配置缺失: $(basename "$platform_file")"
  fi
}

# ======================
# 权限排查
# ======================
check_permissions() {
  echo_step "权限排查"

  local dotfiles_dir="${HOME}/.dotfiles"
  if [[ -d "$dotfiles_dir" ]]; then
    local owner
    owner="$(stat -c '%U' "$dotfiles_dir" 2>/dev/null || stat -f '%Su' "$dotfiles_dir" 2>/dev/null || echo '?')"
    if [[ "$owner" == "$(whoami)" ]]; then
      check_ok ".dotfiles 权限正常（owner: ${owner}）"
    else
      check_fail ".dotfiles 属主异常: ${owner}（应为 $(whoami)）"
    fi
  fi
}

# ======================
# 主流程
# ======================
main() {
  echo_title "Wezterm 环境体检"

  check_core_tools;  echo_separator
  check_configs;     echo_separator
  check_syntax;      echo_separator
  check_platform_config; echo_separator
  check_permissions

  # 复用 check_summary（内部会根据 FAIL 决定是否 exit 1）
  check_summary
}

main
