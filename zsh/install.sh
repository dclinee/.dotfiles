#!/usr/bin/env sh

# ======================
# Zsh 配置安装器
# ======================

set -e

# 确定配置目录
DOTFILES_DIR="${HOME}/.dotfiles/zsh"
ZSH_HOME="${DOTFILES_DIR}"

# 创建必要的目录
mkdir -p "${HOME}/.cache/zsh"
mkdir -p "${DOTFILES_DIR}/plugins"

# 创建符号链接
ln -sf "${DOTFILES_DIR}/.zshrc" "${HOME}/.zshrc" && \
echo "链接创建: ${HOME}/.zshrc -> ${DOTFILES_DIR}/.zshrc"

# 安装 Starship
if ! command -v starship > /dev/null; then
  echo "安装 Starship..."
  curl -sS https://starship.rs/install.sh | sh -s -- -y
fi

# 安装必备工具
if ! command -v eza > /dev/null; then
  if command -v brew > /dev/null; then
    brew install eza zoxide
  elif command -v apt > /dev/null; then
    sudo apt install -y eza zoxide
  elif command -v dnf > /dev/null; then
    sudo dnf install -y eza zoxide
  elif command -v pacman > /dev/null; then
    sudo pacman -S --noconfirm eza zoxide
  else
    echo "无法安装 eza 和 zoxide，请手动安装"
  fi
fi

# 安装插件
install_plugin() {
  plugin_name=$1
  plugin_url=$2
  plugin_dir="${DOTFILES_DIR}/plugins/${plugin_name}"
  
  if [ ! -d "${plugin_dir}" ]; then
    echo "安装插件: ${plugin_name}"
    git clone --depth 1 "${plugin_url}" "${plugin_dir}" > /dev/null 2>&1
  fi
}

install_plugin "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions"
install_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting"
install_plugin "zoxide" "https://github.com/ajeetdsouza/zoxide"
install_plugin "forgit" "https://github.com/wfxr/forgit"

# 初始化 zoxide
if command -v zoxide > /dev/null; then
  echo "初始化 zoxide..."
  zoxide init zsh > "${DOTFILES_DIR}/plugins/zoxide/init.zsh"
fi

# 设置权限
chmod +x "${DOTFILES_DIR}/install.sh"

echo "安装完成！"
echo "请运行: source ~/.zshrc 或重新打开终端"
