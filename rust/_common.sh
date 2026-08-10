#!/usr/bin/env bash

# ======================
# Rust 模块公共加载器（内部文件）
# ======================
#
# 供 rust/ 下所有脚本 source，统一加载 lib/output.sh 和 lib/symlink.sh
# 使用方法: source "$(dirname "$0")/_common.sh"

# 确定项目根目录
RUST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "${RUST_DIR}/.." && pwd)}"

# 加载公共输出函数库
_OUTPUT_LIB="${DOTFILES_ROOT}/lib/output.sh"
if [[ -f "${_OUTPUT_LIB}" ]]; then
  # shellcheck source=/dev/null
  source "${_OUTPUT_LIB}"
else
  RED="\033[31m"; GREEN="\033[32m"; YELLOW="\033[33m"; BLUE="\033[34m"
  CYAN="\033[36m"; RESET="\033[0m"; BOLD="\033[1m"
  CHECK="✅"; INFO="ℹ️"; WARN="⚠️"; ERROR="❌"; ARROW="➡️"; SKIP="⏭️"
  SEPARATOR="${BLUE}=============================================${RESET}"
  echo_step()      { printf "${BOLD}${BLUE}${INFO} %s${RESET}\n"  "${1}"; }
  echo_success()   { printf "${GREEN}${CHECK} %s${RESET}\n"        "${1}"; }
  echo_warning()   { printf "${YELLOW}${WARN} %s${RESET}\n"        "${1}"; }
  echo_error()     { printf "${RED}${ERROR} %s${RESET}\n"          "${1}"; }
  echo_skip()      { printf "${CYAN}${SKIP} %s${RESET}\n"          "${1}"; }
  echo_detail()    { printf "${BLUE}  %s${RESET}\n"                "${1}"; }
  echo_separator() { printf '%b\n' "${SEPARATOR}"; }
  echo_title() {
    echo_separator
    printf "${BOLD}${CYAN}%s${RESET}\n" "${1}"
    echo_separator
  }
fi

# 加载公共符号链接函数库
_SYMLINK_LIB="${DOTFILES_ROOT}/lib/symlink.sh"
if [[ -f "${_SYMLINK_LIB}" ]]; then
  # shellcheck source=/dev/null
  source "${_SYMLINK_LIB}"
else
  safe_symlink() {
    local src="$1" dst="$2"
    [[ -e "$src" ]] || { echo_warning "源文件不存在: $src"; return 1; }
    if [[ -L "$dst" ]] && [[ "$(readlink "$dst" 2>/dev/null)" == "$src" ]]; then
      echo_skip "链接已存在: $dst"; return 0
    fi
    if [[ -e "$dst" ]] || [[ -L "$dst" ]]; then
      local backup="${dst}.bak.$(date +%Y%m%d_%H%M%S 2>/dev/null || echo bak)"
      mv "$dst" "$backup" 2>/dev/null && echo_warning "已备份: $dst → $backup"
    fi
    mkdir -p "$(dirname "$dst")" 2>/dev/null
    ln -sf "$src" "$dst" 2>/dev/null && echo_detail "已链接: $dst → $src" || { echo_error "链接失败: $dst"; return 1; }
  }
fi

# ======================
# 公共工具函数
# ======================

# 解析 tools.list，输出 "包名 版本" 对（版本为空时输出空）
# 用法: read_tools_list | while read -r name version; do ...; done
read_tools_list() {
  local list_file="${RUST_DIR}/tools.list"
  [[ -f "$list_file" ]] || return 1
  while IFS='|' read -r name version || [[ -n "$name" ]]; do
    # 跳过注释和空行
    [[ -z "$name" || "$name" == \#* ]] && continue
    name="$(echo "$name" | xargs)"  # 去除首尾空格
    version="$(echo "$version" | xargs)"
    [[ -n "$name" ]] && echo "$name $version"
  done < "$list_file"
}

# 判断 cargo 是否可用
has_cargo() {
  command -v cargo > /dev/null 2>&1
}

# 判断 rustup 是否可用
has_rustup() {
  command -v rustup > /dev/null 2>&1
}
