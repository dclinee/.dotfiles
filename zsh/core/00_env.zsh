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

# 注: ~/.local/bin 已在 .zshenv 中通过去重逻辑添加，此处不再重复

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
export HISTORY_IGNORE="(ls|cd|pwd|exit|clear)"

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
# 注：已移除对 PYTHONPATH 全局赋值（原: _py_site_packages + ~/.dotfiles/python）
# 把 ~/.dotfiles/python 加入 PYTHONPATH 会干扰其他 Python 项目（如假设有同名模块会被错误导入）
# 项目需要的包应通过 pip/pipx/venv 安装，而非污染全局 PYTHONPATH

# Python 配置文件
export PYTHONSTARTUP="${HOME}/.dotfiles/python/pythonrc.py"
export PIP_CONFIG_FILE="${HOME}/.dotfiles/python/pip.conf"

# Python 虚拟环境
export WORKON_HOME="${HOME}/.virtualenvs"
if command -v python3 > /dev/null 2>&1; then
  export VIRTUALENVWRAPPER_PYTHON="$(command -v python3)"
fi

# 确保 Python 相关目录存在
mkdir -p "${HOME}/.virtualenvs" "${HOME}/.cache/pip" 2>/dev/null

# Dotfiles 专用 venv（由 bootstrap.sh / zsh/install.sh 创建时写入 marker）
# 把该 venv bin 追加到 PATH，避免污染其他项目
_py_venv_marker="${HOME}/.local/share/dotfiles-py-path"
if [[ -f "${_py_venv_marker}" ]]; then
  _py_venv_bin="$(head -n 1 "${_py_venv_marker}" 2>/dev/null || true)"
  if [[ -n "${_py_venv_bin}" ]] && [[ -d "${_py_venv_bin}" ]]; then
    # 仅当未入 PATH 时才追加，避免重复
    case ":${PATH}:" in
      *":${_py_venv_bin}:"*) ;;
      *) export PATH="${PATH}:${_py_venv_bin}" ;;
    esac
  fi
  unset _py_venv_bin
fi
unset _py_venv_marker

# 虚拟环境自动激活/停用 (仅交互式 shell)
# 进入含 .venv 的目录时自动激活，离开时自动停用
_venv_autoswitch() {
  if [[ -d ".venv" ]] && [[ -f ".venv/bin/activate" ]]; then
    # 已激活同一目录的 venv 则跳过
    if [[ -n "${VIRTUAL_ENV:-}" ]] && [[ "${VIRTUAL_ENV:A}" == "${PWD:A}/.venv" ]]; then
      return
    fi
    # 如已激活其他 venv，先停用
    if [[ -n "${VIRTUAL_ENV:-}" ]] && typeset -f deactivate > /dev/null 2>&1; then
      deactivate 2>/dev/null || true
    fi
    source .venv/bin/activate 2>/dev/null || true
  elif [[ -n "${VIRTUAL_ENV:-}" ]] && typeset -f deactivate > /dev/null 2>&1; then
    # 离开 venv 目录时自动停用
    deactivate 2>/dev/null || true
  fi
}

if [[ -o interactive ]]; then
  # 启动时检查当前目录
  _venv_autoswitch
  # cd 时自动切换
  chpwd_functions=(${chpwd_functions[@]} _venv_autoswitch)
fi
