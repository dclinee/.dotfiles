#!/usr/bin/env bash

# ======================
# Wezterm 配置安装器
# ======================

set -euo pipefail
LOG_FILE="/tmp/wezterm_install_$(date +%Y%m%d_%H%M%S).log"

# 确定配置目录
DOTFILES_DIR="${HOME}/.dotfiles"
WEZTERM_DIR="${DOTFILES_DIR}/wezterm"

# 加载公共输出函数（带内联回退）
_OUTPUT_LIB="${DOTFILES_DIR}/zsh/lib/output.sh"
if [[ -f "${_OUTPUT_LIB}" ]]; then
  source "${_OUTPUT_LIB}"
else
  # 内联回退 - 当 lib 不可用时使用
  RED="\033[31m"
  GREEN="\033[32m"
  YELLOW="\033[33m"
  BLUE="\033[34m"
  CYAN="\033[36m"
  WHITE="\033[37m"
  RESET="\033[0m"
  BOLD="\033[1m"
  CHECK="✅"
  INFO="ℹ️"
  WARN="⚠️"
  ERROR="❌"
  ARROW="➡️"
  SEPARATOR="${BLUE}=============================================${RESET}"

  echo_step() { printf "${BOLD}${BLUE}${INFO} %s${RESET}\n" "${1}"; }
  echo_success() { printf "${GREEN}${CHECK} %s${RESET}\n" "${1}"; }
  echo_warning() { printf "${YELLOW}${WARN} %s${RESET}\n" "${1}"; }
  echo_error() { printf "${RED}${ERROR} %s${RESET}\n" "${1}"; }
  echo_separator() { printf '%b\n' "${SEPARATOR}"; }
  echo_title() {
    echo_separator
    printf "${BOLD}${CYAN}%s${RESET}\n" "${1}"
    echo_separator
  }
fi

# 开始安装
echo_title "Wezterm 配置安装器"
echo "安装日志将保存到: ${LOG_FILE}"

# 创建必要的目录
echo_step "创建必要目录..."
mkdir -p "${WEZTERM_DIR}/core" "${WEZTERM_DIR}/platform" 2>/dev/null
echo_success "目录创建完成"

# 检查 Wezterm 是否安装
check_wezterm_install() {
  if ! command -v wezterm > /dev/null; then
    echo_warning "Wezterm 未安装，将只创建配置链接"
    echo_warning "请手动安装 Wezterm:"
    echo_warning "  Linux: sudo apt install wezterm / sudo dnf install wezterm"
    echo_warning "  macOS: brew install --cask wezterm"
    echo_warning "  Windows: winget install WezTerm.WezTerm"
    return 1
  else
    echo_success "Wezterm 已安装: $(wezterm --version)"
    return 0
  fi
}

# 创建配置链接
create_wezterm_link() {
  echo_step "创建 Wezterm 配置链接..."
  
  local link_path="${HOME}/.wezterm.lua"
  local target_path="${WEZTERM_DIR}/wezterm.lua"
  
  if [ -L "${link_path}" ]; then
    # 已存在符号链接，检查是否指向正确位置
    local current_target=$(readlink "${link_path}")
    if [ "${current_target}" == "${target_path}" ]; then
      echo_success "Wezterm 配置链接已存在且指向正确位置"
    else
      echo_warning "更新 Wezterm 配置链接..."
      ln -sf "${target_path}" "${link_path}"
      echo_success "Wezterm 配置链接已更新"
    fi
  elif [ -f "${link_path}" ]; then
    # 已存在文件，备份并创建链接
    echo_warning "发现现有 Wezterm 配置文件，将其备份为 ${link_path}.bak"
    mv "${link_path}" "${link_path}.bak"
    ln -sf "${target_path}" "${link_path}"
    echo_success "已创建 Wezterm 配置链接并备份原有文件"
  else
    # 创建新链接
    ln -sf "${target_path}" "${link_path}"
    echo_success "Wezterm 配置链接创建成功"
  fi
  
  # 验证链接
  echo_step "验证配置链接..."
  ls -la "${link_path}"
}

# 主安装流程
main() {
  # 检查 Wezterm 安装（即使未安装也继续创建配置链接）
  check_wezterm_install || true
  
  # 创建配置链接
  create_wezterm_link
  
  echo_title "安装完成"
  printf "${GREEN}${CHECK} ${BOLD}Wezterm 配置安装完成！${RESET}\n"
  printf "${BOLD}${YELLOW}${ARROW} 配置文件位置:${RESET} %s/wezterm.lua\n" "${WEZTERM_DIR}"
  printf "${BOLD}${YELLOW}${ARROW} 链接位置:${RESET} %s/.wezterm.lua\n" "${HOME}"
  printf "${BOLD}${YELLOW}${ARROW} 启动 Wezterm:${RESET} wezterm\n"
  echo_separator
}

# 执行主流程
main