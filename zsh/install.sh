#!/usr/bin/env bash

# ======================
# Zsh 配置安装器
# ======================

set -euo pipefail
LOG_FILE="/tmp/dotfiles_install_$(date +%Y%m%d_%H%M%S).log"

# 美化输出配置
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
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
SEPARATOR="${BLUE}=============================================${RESET}"

# 确定配置目录
DOTFILES_DIR="${HOME}/.dotfiles/zsh"
ZSH_HOME="${DOTFILES_DIR}"
ZINIT_DIR="${DOTFILES_DIR}/plugins/zinit"
PLUGINS_DIR="${DOTFILES_DIR}/plugins"

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
exec > >(tee -a ${LOG_FILE}) 2>&1
  echo -e "${SEPARATOR}"
}

echo_title() {
  echo_separator
exec > >(tee -a ${LOG_FILE}) 2>&1
  echo -e "${BOLD}${CYAN}${1}${RESET}"
  echo_separator
exec > >(tee -a ${LOG_FILE}) 2>&1
}

# 开始安装
echo_title "Zsh 配置安装器"
echo "安装日志将保存到: ${LOG_FILE}"

# 创建必要的目录
echo_step "创建必要目录..."
mkdir -p "${HOME}/.cache/zsh" "${DOTFILES_DIR}/plugins"
echo_success "目录创建完成"

# 创建 .zshrc 符号链接
echo_step "配置 .zshrc 符号链接..."
if [ ! -L "${HOME}/.zshrc" ]; then
  ln -sf "${DOTFILES_DIR}/.zshrc" "${HOME}/.zshrc"
  echo_success "已创建 .zshrc 符号链接"
else
  echo_warning ".zshrc 符号链接已存在"
fi
# 安装 zinit 插件管理器
install_zinit() {
  if [ ! -d "${ZINIT_DIR}" ]; then
    echo_step "正在安装 zinit 插件管理器..."
    # 尝试官方源，失败则使用国内镜像
    if ! git clone --depth 1 https://github.com/zdharma-continuum/zinit.git "${ZINIT_DIR}" > /dev/null 2>&1; then
      echo_warning "官方源克隆失败，尝试国内镜像..."
      git clone --depth 1 https://gitee.com/mirrors/zinit.git "${ZINIT_DIR}" > /dev/null 2>&1
    fi
    echo_success "zinit 安装成功"
  else
    echo_success "zinit 已安装"
  fi
}

# 初始化 zinit
init_zinit() {
  if [ -f "${ZINIT_DIR}/zinit.zsh" ]; then
    echo_step "初始化 zinit..."
    # 使用 zsh 来执行 zinit 初始化，避免 Bash 不兼容问题
    zsh -c "source \"${ZINIT_DIR}/zinit.zsh\"" > /dev/null 2>&1
    echo_success "zinit 初始化完成"
  else
    echo_error "zinit 未找到，请检查安装"
    exit 1
  fi
}

# 通过 zinit 安装插件
install_plugin() {
  local plugin_id=$1
  local plugin_name=$2
  
  # 检查插件是否已安装
  if ! zsh -c "source \"${ZINIT_DIR}/zinit.zsh\" && zinit list | grep -q '${plugin_id}'" > /dev/null 2>&1; then
    echo -e "${BOLD}${CYAN}${ARROW} 安装插件: ${plugin_name}${RESET}"
    zsh -c "source \"${ZINIT_DIR}/zinit.zsh\" && zinit light '${plugin_id}'" > /dev/null 2>&1
    echo_success "${plugin_name} 插件安装完成"
  else
    echo_success "${plugin_name} 插件已安装"
  fi
}

# 安装必备工具
install_essential_tools() {
  echo_step "检查必备工具..."
  
  # 安装 starship 主题
  if ! command -v starship > /dev/null; then
    echo -e "${BOLD}${CYAN}${ARROW} 安装 starship 主题...${RESET}"
    curl -sS https://starship.rs/install.sh | sh -s -- -y > /dev/null 2>&1
    echo_success "starship 安装完成"
  else
    echo_success "starship 已安装"
  fi
  
  # 安装 eza 和 zoxide
  if ! command -v eza > /dev/null || ! command -v zoxide > /dev/null; then
    echo -e "${BOLD}${CYAN}${ARROW} 安装 eza 和 zoxide...${RESET}"
    if command -v brew > /dev/null; then
      brew install eza zoxide > /dev/null 2>&1
      echo_success "eza 和 zoxide 安装完成"
    elif command -v apt > /dev/null; then
      sudo apt update > /dev/null 2>&1
      sudo apt install -y eza zoxide > /dev/null 2>&1
      echo_success "eza 和 zoxide 安装完成"
    elif command -v dnf > /dev/null; then
      sudo dnf install -y eza zoxide > /dev/null 2>&1
      echo_success "eza 和 zoxide 安装完成"
    elif command -v pacman > /dev/null; then
      sudo pacman -S --noconfirm eza zoxide > /dev/null 2>&1
      echo_success "eza 和 zoxide 安装完成"
    else
      echo_warning "无法自动安装 eza 或 zoxide，请手动安装"
    fi
  else
    echo_success "eza 和 zoxide 已安装"
  fi
}

# 安装 Python 配置和依赖
install_python_config() {
  echo_step "配置 Python 环境..."
  
  # 检查 Python 3 是否安装
  if ! command -v python3 > /dev/null; then
    echo_error "Python 3 未安装，请先安装 Python 3"
    return 1
  fi
  
  # 检查 pip 是否安装
  if ! command -v pip3 > /dev/null; then
    echo -e "${BOLD}${CYAN}${ARROW} 安装 pip...${RESET}"
    python3 -m ensurepip --upgrade > /dev/null 2>&1
    echo_success "pip 安装完成"
  fi
  
  # 安装 Python 依赖
  if [ -f "${HOME}/.dotfiles/python/requirements.txt" ]; then
    echo -e "${BOLD}${CYAN}${ARROW} 安装 Python 依赖...${RESET}"
    pip3 install --upgrade -r "${HOME}/.dotfiles/python/requirements.txt" > /dev/null 2>&1
    echo_success "Python 依赖安装完成"
  fi
  
  # 确保 Python 相关目录存在
  mkdir -p "${HOME}/.virtualenvs" "${HOME}/.cache/pip" > /dev/null 2>&1
  
  # 配置 pip 符号链接（可选，已通过环境变量配置）
  if [ ! -L "${HOME}/.pip/pip.conf" ] && [ ! -f "${HOME}/.pip/pip.conf" ]; then
    mkdir -p "${HOME}/.pip" > /dev/null 2>&1
    ln -sf "${HOME}/.dotfiles/python/pip.conf" "${HOME}/.pip/pip.conf" > /dev/null 2>&1
    echo_success "已创建 pip.conf 符号链接"
  fi
  
  echo_success "Python 环境配置完成"
}

# 主安装流程
main() {
  # 安装必备工具
  install_essential_tools
  
  echo_separator
exec > >(tee -a ${LOG_FILE}) 2>&1
  
  # 安装并初始化 zinit
  install_zinit
  init_zinit
  
  echo_separator
exec > >(tee -a ${LOG_FILE}) 2>&1
  
  # 通过 zinit 安装插件
  echo_step "安装 zinit 插件..."
  install_plugin "zsh-users/zsh-autosuggestions" "自动补全"
  install_plugin "zsh-users/zsh-syntax-highlighting" "语法高亮"
  install_plugin "wfxr/forgit" "Git 快捷操作"
  install_plugin "zsh-users/zsh-history-substring-search" "历史命令搜索"
  install_plugin "agkozak/zsh-z" "目录跳转增强"
  
  echo_separator
exec > >(tee -a ${LOG_FILE}) 2>&1
  
  # 配置 Python 环境
  install_python_config
  
  echo_separator
exec > >(tee -a ${LOG_FILE}) 2>&1
  
  # 初始化 zoxide
  if command -v zoxide > /dev/null; then
    echo_step "初始化 zoxide..."
    mkdir -p "${PLUGINS_DIR}/zoxide"
    zoxide init zsh > "${PLUGINS_DIR}/zoxide/init.zsh" > /dev/null 2>&1
    echo_success "zoxide 初始化完成"
  fi
  
  echo_title "安装完成"
  echo -e "${GREEN}${CHECK} ${BOLD}所有配置安装完成！${RESET}"
  echo -e "${BOLD}${YELLOW}${ARROW} 请执行以下命令生效：${RESET}"
  echo -e "${BOLD}${WHITE}source ~/.zshrc${RESET}"
  echo -e "${BOLD}${YELLOW}${ARROW} 或重启终端${RESET}"
  echo_separator
exec > >(tee -a ${LOG_FILE}) 2>&1
}

# 执行主流程
main

