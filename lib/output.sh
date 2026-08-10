#!/usr/bin/env bash

# ======================
# 公共输出函数库
# ======================
#
# 提供统一的终端美化输出函数
# 适用于 bash 和 zsh 脚本
#
# 使用方法:
#   source "${DOTFILES_DIR}/lib/output.sh"
#   echo_step "开始执行"
#   echo_success "完成"

# 颜色定义
if [[ -z "${__OUTPUT_SH_LOADED:-}" ]]; then
  export __OUTPUT_SH_LOADED=1

  RED="\033[31m"
  GREEN="\033[32m"
  YELLOW="\033[33m"
  BLUE="\033[34m"
  CYAN="\033[36m"
  WHITE="\033[37m"
  RESET="\033[0m"
  BOLD="\033[1m"

  # 图标配置
  CHECK="✅"
  INFO="ℹ️"
  WARN="⚠️"
  ERROR="❌"
  ARROW="➡️"
  SKIP="⏭️"

  # 分隔线
  SEPARATOR="${BLUE}============================================${RESET}"

# 输出美化函数
echo_step() {
  printf "${BOLD}${BLUE}${INFO} %s${RESET}\n" "${1}"
}

echo_success() {
  printf "${GREEN}${CHECK} %s${RESET}\n" "${1}"
}

echo_warning() {
  printf "${YELLOW}${WARN} %s${RESET}\n" "${1}"
}

echo_error() {
  printf "${RED}${ERROR} %s${RESET}\n" "${1}"
}

echo_skip() {
  printf "${CYAN}${SKIP} %s${RESET}\n" "${1}"
}

echo_detail() {
  printf "${BLUE}  %s${RESET}\n" "${1}"
}

echo_separator() {
  printf '%b\n' "${SEPARATOR}"
}

echo_title() {
  echo_separator
  printf "${BOLD}${CYAN}%s${RESET}\n" "${1}"
  echo_separator
}
fi
