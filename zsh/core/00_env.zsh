#!/usr/bin/env zsh

# ======================
# 环境变量配置
# ======================

# ZSH 配置入口
export ZSH_HOME="${HOME}/.dotfiles/zsh"
export ZINIT_DIR="${ZSH_HOME}/plugins/zinit"

# 基础路径设置 - 只添加自定义路径，保持系统默认PATH
if [[ -d "${HOME}/.local/bin" ]]; then
  export PATH="${HOME}/.local/bin:${PATH}"
fi

# Homebrew 路径配置 - 根据架构和系统自动设置
if [[ "$(uname -m)" == "arm64" ]] && [[ "$(uname -s)" == "Darwin" ]]; then
  # macOS ARM64
  if [[ -d "/opt/homebrew/bin" ]]; then
    export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:${PATH}"
    export HOMEBREW_PREFIX="/opt/homebrew"
  fi
elif [[ "$(uname -s)" == "Linux" ]]; then
  # Linux
  if [[ -d "/home/linuxbrew/.linuxbrew/bin" ]]; then
    export PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"
    export HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
  fi
elif [[ "$(uname -s)" == "Darwin" ]]; then
  # macOS x86_64
  if [[ -d "/usr/local/bin" ]]; then
    export PATH="/usr/local/bin:/usr/local/sbin:${PATH}"
    export HOMEBREW_PREFIX="/usr/local"
  fi
fi

# 默认编辑器 - 智能选择可用的编辑器
if command -v emacs > /dev/null; then
  export EDITOR='emacs'
  export VISUAL='emacs'
elif command -v vim > /dev/null; then
  export EDITOR='vim'
  export VISUAL='vim'
elif command -v nvim > /dev/null; then
  export EDITOR='nvim'
  export VISUAL='nvim'
fi

# 语言设置
export LANG='en_US.UTF-8'
export LC_ALL='en_US.UTF-8'

# 历史记录优化
export HISTSIZE=100000
export SAVEHIST=100000
export HISTFILE="${HOME}/.cache/zsh/history"

# 历史记录增强选项
export HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S "  # 显示时间戳
export HISTORY_IGNORE="(ls|cd|pwd|exit|clear)"  # 忽略常见命令
export HIST_FCNTL_LOCK="2"  # 使用fcntl锁定历史文件
export HIST_SAVE_BY_COPY="yes"  # 保存历史时使用复制而不是重命名
export HIST_REDUCE_BLANKS="yes"  # 移除空白行

# 确保历史记录目录存在
mkdir -p "${HOME}/.cache/zsh" 2>/dev/null

# Starship 配置路径
export STARSHIP_CONFIG="${ZSH_HOME}/starship.toml"
export STARSHIP_SHELL="zsh"

# ----------------------
# Python 配置
# ----------------------
# Python 版本管理
export PYENV_ROOT="${HOME}/.pyenv"
if [[ -d "${PYENV_ROOT}" ]]; then
  export PATH="${PYENV_ROOT}/bin:${PATH}"
  eval "$(pyenv init --path)" 2>/dev/null || true
  eval "$(pyenv init -s)" 2>/dev/null || true
  
  # 添加 pyenv virtualenv 支持
  if command -v pyenv-virtualenv > /dev/null; then
    eval "$(pyenv virtualenv-init -)" 2>/dev/null || true
  fi
fi

# 添加 dotfiles python 模块路径
export PYTHONPATH="${HOME}/.dotfiles/python:${PYTHONPATH}"
# 添加本地 Python 库路径
export PYTHONPATH="${HOME}/.local/lib/python3.*/site-packages:${PYTHONPATH}"

# Python 配置文件
export PYTHONSTARTUP="${HOME}/.dotfiles/python/pythonrc.py"
export PIP_CONFIG_FILE="${HOME}/.dotfiles/python/pip.conf"

# Python 虚拟环境
export WORKON_HOME="${HOME}/.virtualenvs"
export VIRTUALENVWRAPPER_PYTHON="$(command -v python3)"

# 确保 Python 相关目录存在
mkdir -p "${HOME}/.virtualenvs" "${HOME}/.cache/pip" 2>/dev/null

# 虚拟环境自动激活
# 如果当前目录存在 .venv 目录，自动激活
if [[ -d ".venv" ]]; then
  source .venv/bin/activate 2>/dev/null || true
fi

# 创建Vim配置符号链接
if [[ ! -L "${HOME}/.vimrc" ]] || [[ "$(readlink "${HOME}/.vimrc")" != "${HOME}/.dotfiles/vim/.vimrc" ]]; then
  ln -sf "${HOME}/.dotfiles/vim/.vimrc" "${HOME}/.vimrc"
fi
