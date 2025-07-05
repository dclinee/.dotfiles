#!/usr/bin/env zsh

# ======================
# 主入口配置文件
# ======================

# 基础配置目录
DOTFILES_DIR="${HOME}/.dotfiles/zsh"
ZSH_HOME="${DOTFILES_DIR}"

# 加载核心模块
for config in ${ZSH_HOME}/core/*.zsh; do
  # 跳过非标准文件和目录
  # 原代码（行13）
  [[ ${config} =~ ".*/core/\\..*" ]] && continue
  [[ -d ${config} ]] && continue
  
  source "${config}"
done
unset config

# 加载平台专用配置
case "$OSTYPE" in
  darwin*) 
    [[ -f "${ZSH_HOME}/platform/macos.zsh" ]] && source "${ZSH_HOME}/platform/macos.zsh" 
    ;;
  linux*) 
    [[ -f "${ZSH_HOME}/platform/linux.zsh" ]] && source "${ZSH_HOME}/platform/linux.zsh" 
    ;;
esac

# 加载本地覆盖配置
[[ -f "${HOME}/.zshrc.local" ]] && source "${HOME}/.zshrc.local"
eval "$(starship init zsh)"

# 使用 zinit 的配置示例
if [[ ! -f "${ZSH_HOME}/lib/zinit.zsh" ]]; then
  [[ ! -d "${ZSH_HOME}/lib/zinit" ]] && \
    git clone https://github.com/zdharma-continuum/zinit "${ZSH_HOME}/lib/zinit"
fi
source "${ZSH_HOME}/lib/zinit/zinit.zsh"

# 异步加载插件
zinit light-mode for \
  zdharma-continuum/zinit-annex-as-monitor \
  zdharma-continuum/zinit-annex-bin-gem-node \
  zsh-users/zsh-autosuggestions \
  zsh-users/zsh-syntax-highlighting
