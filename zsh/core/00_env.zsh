#!/usr/bin/env zsh

# ======================
# 环境变量配置
# ======================

# 基础路径设置
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export PATH="${HOME}/.local/bin:${PATH}"

# 默认编辑器
export EDITOR='nvim'
export VISUAL='nvim'

# 语言设置
export LANG='en_US.UTF-8'
export LC_ALL='en_US.UTF-8'

# 历史记录设置
export HISTSIZE=100000
export SAVEHIST=100000
export HISTFILE="${HOME}/.cache/zsh/history"

# Starship 配置路径
export STARSHIP_CONFIG="${ZSH_HOME}/starship.toml"

# ARM架构Homebrew路径
if [[ "$(uname -m)" == "arm64" ]]; then
  export PATH="/opt/homebrew/bin:$PATH"
fi

# x86架构Linux专用路径
if [[ "$(uname -s)" == "Linux" ]]; then
  export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
fi
