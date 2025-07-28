#!/usr/bin/env sh

# ======================
# Zsh 配置安装器
# ======================

set -e

# 确定配置目录
DOTFILES_DIR="${HOME}/.dotfiles/zsh"
ZSH_HOME="${DOTFILES_DIR}"
ZINIT_DIR="${DOTFILES_DIR}/plugins/zinit"
PLUGINS_DIR="${DOTFILES_DIR}/plugins"

# 创建必要的目录
mkdir -p "${HOME}/.cache/zsh"
mkdir -p "${DOTFILES_DIR}/plugins"

# 创建 .zshrc 符号链接
if [ ! -L "${HOME}/.zshrc" ]; then
  ln -sf "${DOTFILES_DIR}/.zshrc" "${HOME}/.zshrc"
  echo "已创建 .zshrc 符号链接"
else
  echo ".zshrc 符号链接已存在"
fi
# 安装 zinit 插件管理器
install_zinit() {
  if [ ! -d "${ZINIT_DIR}" ]; then
    echo "正在安装 zinit 插件管理器..."
    # 尝试官方源，失败则使用国内镜像
    if ! git clone --depth 1 https://github.com/zdharma-continuum/zinit.git "${ZINIT_DIR}" > /dev/null 2>&1; then
      echo "官方源克隆失败，尝试国内镜像..."
      git clone --depth 1 https://gitee.com/mirrors/zinit.git "${ZINIT_DIR}" > /dev/null 2>&1
    fi
  else
    echo "zinit 已安装"
  fi
}

# 初始化 zinit
init_zinit() {
  if [ -f "${ZINIT_DIR}/zinit.zsh" ]; then
    source "${ZINIT_DIR}/zinit.zsh"
    echo "zinit 初始化完成"
  else
    echo "错误：zinit 未找到，请检查安装"
    exit 1
  fi
}

# 通过 zinit 安装插件
install_plugin() {
  local plugin_id=$1
  local plugin_name=$2
  
  # 检查插件是否已安装
  if ! zinit list | grep -q "${plugin_id}"; then
    echo "安装插件: ${plugin_name}"
    zinit light "${plugin_id}"
  else
    echo "插件 ${plugin_name} 已安装"
  fi
}

# 安装必备工具
install_essential_tools() {
  echo "检查必备工具..."
  
  # 安装 starship 主题
  if ! command -v starship > /dev/null; then
    echo "安装 starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y
  fi
  
  # 安装 eza 和 zoxide
  if ! command -v eza > /dev/null || ! command -v zoxide > /dev/null; then
    if command -v brew > /dev/null; then
      brew install eza zoxide
    elif command -v apt > /dev/null; then
      sudo apt update && sudo apt install -y eza zoxide
    elif command -v dnf > /dev/null; then
      sudo dnf install -y eza zoxide
    elif command -v pacman > /dev/null; then
      sudo pacman -S --noconfirm eza zoxide
    else
      echo "警告：无法自动安装 eza 或 zoxide，请手动安装"
    fi
  fi
}

# 主安装流程
main() {
  # 安装必备工具
  install_essential_tools
  
  # 安装并初始化 zinit
  install_zinit
  init_zinit
  
  # 通过 zinit 安装插件
  install_plugin "zsh-users/zsh-autosuggestions" "自动补全"
  install_plugin "zsh-users/zsh-syntax-highlighting" "语法高亮"
  install_plugin "wfxr/forgit" "Git 快捷操作"
  install_plugin "zsh-users/zsh-history-substring-search" "历史命令搜索"
  install_plugin "agkozak/zsh-z" "目录跳转增强"
  
  # 初始化 zoxide
  if command -v zoxide > /dev/null; then
    mkdir -p "${PLUGINS_DIR}/zoxide"
    zoxide init zsh > "${PLUGINS_DIR}/zoxide/init.zsh"
    echo "zoxide 初始化完成"
  fi
  
  echo "所有配置安装完成！"
  echo "请执行 source ~/.zshrc 或重启终端生效"
}

# 执行主流程
main

