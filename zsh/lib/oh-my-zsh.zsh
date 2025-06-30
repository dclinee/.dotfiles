#!/usr/bin/env zsh

# ======================
# Oh-My-Zsh 精简兼容层
# ======================

# 定义必要的全局变量
export ZSH="${ZSH_HOME}/themes/oh-my-zsh"
export ZSH_CUSTOM="${ZSH_HOME}/themes/custom"

# 加载必要的基础函数
autoload -Uz colors && colors

# 定义 Oh-My-Zsh 风格的主题函数
prompt_clean() {
  PROMPT='%{$fg[green]%}%n@%m %{$fg[blue]%}%~%{$reset_color%}%(#.#.$) '
  RPROMPT=''
}

# Git 相关辅助函数
function current_branch() {
  git branch --show-current 2>/dev/null
}

function parse_git_dirty() {
  if command git status --porcelain 2>/dev/null | grep -q '^.[^?]'; then
    echo "*"
  fi
}
