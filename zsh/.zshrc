#!/usr/bin/env zsh

# ======================
# 主入口配置文件
# ======================

# 加载核心配置模块
for file in "${HOME}/.dotfiles/zsh/core"/*.zsh; do
  [ -f "$file" ] && [ ! -d "$file" ] && source "$file"
done

# 按系统加载平台配置
case "$(uname -s)" in
  Darwin)
    [ -f "${ZSH_HOME}/platform/macos.zsh" ] && source "${ZSH_HOME}/platform/macos.zsh"
    ;;
  Linux)
    [ -f "${ZSH_HOME}/platform/linux.zsh" ] && source "${ZSH_HOME}/platform/linux.zsh"
    ;;
esac

# 加载本地自定义配置（不会被仓库覆盖）
[ -f "${HOME}/.zshrc.local" ] && source "${HOME}/.zshrc.local"
