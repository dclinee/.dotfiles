#!/usr/bin/env zsh

# ======================
# 环境变量配置
# ======================

# 启动性能计时（ZSH_PROFILE=1 时记录开始时间，在 .zshrc 末尾输出）
if [[ "${ZSH_PROFILE:-0}" == "1" ]]; then
  zmodload zsh/datetime
  typeset -gF _zsh_start_time=$EPOCHREALTIME
fi

# ZSH 配置入口
export ZSH_HOME="${HOME}/.dotfiles/zsh"

# 基础路径设置
if [[ -d "${HOME}/.local/bin" ]]; then
  export PATH="${HOME}/.local/bin:${PATH}"
fi

# Homebrew 路径配置
# 注：HOMEBREW_PREFIX 已由 .zshenv 统一设置，此处仅 fallback
if [[ -z "${HOMEBREW_PREFIX:-}" ]] && command -v brew > /dev/null 2>&1; then
  export HOMEBREW_PREFIX="$(brew --prefix 2>/dev/null || echo '')"
fi

# 默认编辑器 - 优先 nvim，然后 vim，最后其他
local _editor
for _editor in nvim vim vi nano emacs; do
  if command -v "$_editor" > /dev/null 2>&1; then
    export EDITOR="$_editor"
    export VISUAL="$_editor"
    break
  fi
done
unset _editor

# 语言设置：LANG 兜底为 en_US.UTF-8；LC_ALL 仅在用户未设时赋值（避免覆盖用户偏好）
: "${LANG:=en_US.UTF-8}"; export LANG
: "${LC_ALL:=en_US.UTF-8}"; export LC_ALL

# 历史记录优化
export HISTSIZE=100000
export SAVEHIST=100000
export HISTFILE="${HOME}/.cache/zsh/history"

# 历史记录增强选项（在 01_options.zsh 中通过 setopt 设置）
export HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S "
export HISTORY_IGNORE_ALL="(ls|cd|pwd|exit|clear)"
export HIST_FCNTL_LOCK="2"
export HIST_SAVE_BY_COPY="yes"
export HIST_REDUCE_BLANKS="yes"

# 确保历史记录目录存在
mkdir -p "${HOME}/.cache/zsh" 2>/dev/null

# ----------------------
# Python 配置
# ----------------------
# Python 版本管理 (懒加载，减少启动开销)
export PYENV_ROOT="${HOME}/.pyenv"
if [[ -d "${PYENV_ROOT}/bin" ]]; then
  export PATH="${PYENV_ROOT}/bin:${PATH}"
  # 懒加载: 首次调用 pyenv 时才初始化
  pyenv() {
    unset -f pyenv
    eval "$(command pyenv init -)" 2>/dev/null || true
    if command -v pyenv-virtualenv > /dev/null 2>&1; then
      eval "$(pyenv virtualenv-init -)" 2>/dev/null || true
    fi
    pyenv "$@"
  }
fi

# Python 模块路径（先 glob 展开，再赋值）
local _py_site_packages=""
for dir in ${HOME}/.local/lib/python*/site-packages(N); do
  [[ -d "$dir" ]] && _py_site_packages="${_py_site_packages}:${dir}"
done
unset PYTHONPATH
export PYTHONPATH="${_py_site_packages}:${HOME}/.dotfiles/python"

# Python 配置文件
export PYTHONSTARTUP="${HOME}/.dotfiles/python/pythonrc.py"
export PIP_CONFIG_FILE="${HOME}/.dotfiles/python/pip.conf"

# Python 虚拟环境
export WORKON_HOME="${HOME}/.virtualenvs"
export VIRTUALENVWRAPPER_PYTHON="$(command -v python3)"

# 确保 Python 相关目录存在
mkdir -p "${HOME}/.virtualenvs" "${HOME}/.cache/pip" 2>/dev/null

# 虚拟环境自动激活 (仅交互式 shell)
if [[ -o interactive ]] && [[ -d ".venv" ]]; then
  source .venv/bin/activate 2>/dev/null || true
fi
