#!/usr/bin/env zsh

# ======================
# 自定义函数
# ======================

# 创建目录并进入
mkcd() { mkdir -p "$@" && cd "${@: -1}" || return; }

# 快速备份文件
bak() { cp -v "$1"{,.bak}; }

# 提取各类压缩包
extract() {
  if [ -f "$1" ]; then
    case "$1" in
      *.tar.gz)  tar xvzf "$1" ;;
      *.tar.bz2) tar xvjf "$1" ;;
      *.zip)     unzip "$1" ;;
      *.rar)     unrar x "$1" ;;
      *.7z)      7z x "$1" ;;
      *)         echo "Unsupported format: $1" ;;
    esac
  else
    echo "File not found: $1"
  fi
}

# 查找进程
psg() {
  ps aux | grep -v grep | grep -i "$1"
}

# 创建新目录并初始化为 Git 仓库
git-init() {
  mkdir "$1" && cd "$1"
  git init
  touch README.md
  git add README.md
  git commit -m "Initial commit"
}
