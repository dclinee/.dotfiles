#!/usr/bin/env zsh

# ======================
# 主入口配置文件
# ======================

# 基础配置目录
DOTFILES_DIR="${HOME}/.dotfiles/zsh"
ZSH_HOME="${DOTFILES_DIR}"
# ZSH 配置入口
export ZSH_HOME="${HOME}/.dotfiles/zsh"
export ZINIT_DIR="${ZSH_HOME}/plugins/zinit"

# 初始化 zinit
if [ -f "${ZINIT_DIR}/zinit.zsh" ]; then
  source "${ZINIT_DIR}/zinit.zsh"
else
  echo "警告：zinit 未找到，请重新运行 install.sh"
fi

# 加载核心配置模块
for file in "${ZSH_HOME}/core"/*.zsh; do
  [ -f "$file" ] && [ ! -d "$file" ] && source "$file"
done

# 按系统加载平台配置
case "$OSTYPE" in
  darwin*)
    [ -f "${ZSH_HOME}/platform/darwin.zsh" ] && source "${ZSH_HOME}/platform/darwin.zsh"
    ;;
  linux*)
    [ -f "${ZSH_HOME}/platform/linux.zsh" ] && source "${ZSH_HOME}/platform/linux.zsh"
    ;;
esac

# 加载 zinit 插件配置
zinit load zsh-users/zsh-autosuggestions
zinit load zsh-users/zsh-syntax-highlighting
zinit load wfxr/forgit
zinit load zsh-users/zsh-history-substring-search
zinit load agkozak/zsh-z

# 配置历史命令搜索插件
bindkey '^[[A' history-substring-search-up   # 上箭头
bindkey '^[[B' history-substring-search-down # 下箭头

# 初始化 zoxide
[ -f "${ZSH_HOME}/plugins/zoxide/init.zsh" ] && source "${ZSH_HOME}/plugins/zoxide/init.zsh"

# 初始化 starship 主题
if command -v starship > /dev/null; then
  eval "$(starship init zsh)"
fi

# 加载本地自定义配置（不会被仓库覆盖）
[ -f "${HOME}/.zshrc.local" ] && source "${HOME}/.zshrc.local"

