#!/usr/bin/env zsh

# ======================
# Zsh 选项配置
# ======================

# 自动补全
autoload -Uz compinit && compinit -d "${HOME}/.cache/zsh/zcompdump"
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# 历史记录配置
setopt append_history
setopt extended_history
setopt hist_ignore_dups
setopt hist_ignore_space
setopt share_history

# 其他优化选项
setopt auto_cd
setopt interactive_comments
setopt no_beep
setopt correct
setopt globdots
