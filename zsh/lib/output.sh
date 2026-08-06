#!/usr/bin/env bash

# ======================
# 公共输出函数库
# ======================
#
# 提供统一的终端美化输出函数
# 适用于 bash 和 zsh 脚本
#
# 使用方法:
#   source "${DOTFILES_DIR}/zsh/lib/output.sh"
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

  # 分隔线
  SEPARATOR="${BLUE}============================================${RESET}"
fi

# 输出美化函数
echo_step() {
  echo -e "${BOLD}${BLUE}${INFO} ${1}${RESET}"
}

echo_success() {
  echo -e "${GREEN}${CHECK} ${1}${RESET}"
}

echo_warning() {
  echo -e "${YELLOW}${WARN} ${1}${RESET}"
}

echo_error() {
  echo -e "${RED}${ERROR} ${1}${RESET}"
}

echo_separator() {
  echo -e "${SEPARATOR}"
}

echo_title() {
  echo_separator
  echo -e "${BOLD}${CYAN}${1}${RESET}"
  echo_separator
}
