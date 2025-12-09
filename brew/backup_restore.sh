#!/usr/bin/env bash
# Brew 配置备份与恢复脚本

# 备份
backup() {
  echo "正在备份 Brew 配置..."
  cd "$(dirname "$0")"
  brew bundle dump --force --file=Brewfile.backup
  echo "备份完成：Brewfile.backup"
}

# 恢复
restore() {
  echo "正在恢复 Brew 配置..."
  cd "$(dirname "$0")"
  if [ -f "Brewfile.backup" ]; then
    brew bundle --file=Brewfile.backup
    echo "恢复完成"
  else
    echo "错误：Brewfile.backup 不存在"
    exit 1
  fi
}

# 执行命令
case "$1" in
  backup) backup ;;
  restore) restore ;;
  *) echo "用法：$0 {backup|restore}" ;;
esac
