#!/usr/bin/env zsh

# ======================
# 别名配置
# ======================

# 通用别名
alias ls='exa --group-directories-first --icons'
alias ll='ls -l'
alias la='ls -a'
alias lt='ls -T'
alias grep='grep --color=auto'
alias df='df -h'
alias du='du -h'
alias vim='nvim'

# Git 别名
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gcm='git commit -m'
alias gp='git push'
alias gpl='git pull'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gd='git diff'
alias gl='git log --oneline --graph'

# 安全操作
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# 平台特定别名在 platform/ 文件中定义
