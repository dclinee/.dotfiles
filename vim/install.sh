#!/usr/bin/env bash

# ======================
# Vim 配置安装器
# ======================

set -euo pipefail
LOG_FILE="/tmp/vim_install_$(date +%Y%m%d_%H%M%S).log"

# 确定配置目录
DOTFILES_DIR="${HOME}/.dotfiles"
VIM_DIR="${DOTFILES_DIR}/vim"

# 颜色定义
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
CYAN="\033[36m"
RESET="\033[0m"
BOLD="\033[1m"

echo_step()    { echo -e "${BOLD}${BLUE}ℹ️  ${1}${RESET}"; }
echo_success() { echo -e "${GREEN}✅ ${1}${RESET}"; }
echo_warning() { echo -e "${YELLOW}⚠️  ${1}${RESET}"; }
echo_error()   { echo -e "${RED}❌ ${1}${RESET}"; }
echo_title() {
  echo -e "${BLUE}=============================================${RESET}"
  echo -e "${BOLD}${CYAN}${1}${RESET}"
  echo -e "${BLUE}=============================================${RESET}"
}

# ======================
# 创建 .vimrc 链接
# ======================
create_vimrc_link() {
  echo_step "配置 .vimrc 符号链接..."

  local vimrc_src="${VIM_DIR}/.vimrc"
  local vimrc_dst="${HOME}/.vimrc"

  if [[ ! -f "${vimrc_src}" ]]; then
    echo_error "源文件不存在: ${vimrc_src}"
    return 1
  fi

  if [[ -L "${vimrc_dst}" ]]; then
    local current_target
    current_target=$(readlink "${vimrc_dst}")
    if [[ "${current_target}" == "${vimrc_src}" ]]; then
      echo_success ".vimrc 链接已存在且指向正确位置"
      return 0
    fi
    echo_warning "更新 .vimrc 链接..."
    rm -f "${vimrc_dst}"
  elif [[ -f "${vimrc_dst}" ]]; then
    echo_warning "发现现有 .vimrc，备份为 .vimrc.bak"
    mv "${vimrc_dst}" "${vimrc_dst}.bak"
  fi

  ln -sf "${vimrc_src}" "${vimrc_dst}"
  echo_success ".vimrc 链接已创建"
}

# ======================
# 创建缓存目录
# ======================
create_cache_dirs() {
  echo_step "创建 Vim 缓存目录..."

  mkdir -p "${HOME}/.cache/vim/undo"
  mkdir -p "${HOME}/.cache/vim/backup"
  mkdir -p "${HOME}/.cache/vim/swap"

  echo_success "缓存目录已创建"
}

# ======================
# 安装 vim-plug
# ======================
install_vim_plug() {
  echo_step "检查 vim-plug 插件管理器..."

  local plug_file="${HOME}/.vim/autoload/plug.vim"

  if [[ -f "${plug_file}" ]]; then
    echo_success "vim-plug 已安装"
    return 0
  fi

  echo_step "安装 vim-plug..."
  if curl -fLo "${plug_file}" --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim 2>>"${LOG_FILE}"; then
    echo_success "vim-plug 安装完成"
    echo_warning "首次打开 Vim 时将自动安装插件"
  else
    echo_warning "vim-plug 安装失败，请手动安装"
    echo "  curl -fLo ~/.vim/autoload/plug.vim --create-dirs \\"
    echo "    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"
  fi
}

# ======================
# 主流程
# ======================
main() {
  echo_title "Vim 配置安装器"
  echo "安装日志: ${LOG_FILE}"

  # 检查 Vim 是否安装
  if command -v vim > /dev/null 2>&1; then
    echo_success "Vim 已安装: $(vim --version | head -1)"
  else
    echo_warning "Vim 未安装"
    if command -v brew > /dev/null 2>&1; then
      echo_step "通过 brew 安装 Vim..."
      brew install vim 2>>"${LOG_FILE}" && echo_success "Vim 安装完成"
    elif command -v apt > /dev/null 2>&1; then
      sudo apt install -y vim 2>>"${LOG_FILE}" && echo_success "Vim 安装完成"
    else
      echo_warning "请手动安装 Vim 后重试"
    fi
  fi

  echo_separator() { echo -e "${BLUE}=============================================${RESET}"; }

  echo_separator

  create_vimrc_link
  create_cache_dirs
  install_vim_plug

  echo_separator
  echo -e "${GREEN}✅ ${BOLD}Vim 配置安装完成！${RESET}"
  echo -e "${YELLOW}首次打开 Vim 将自动安装插件${RESET}"
  echo -e "${YELLOW}或手动执行: vim +PlugInstall +qa${RESET}"
}

main
