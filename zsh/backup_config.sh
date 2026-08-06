#!/usr/bin/env bash
# Zsh 配置备份脚本
set -euo pipefail

BACKUP_DIR="${HOME}/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "${BACKUP_DIR}"

echo "正在备份 Zsh 配置到 ${BACKUP_DIR}..."

# 备份核心配置
if [[ -d "${HOME}/.dotfiles/zsh" ]]; then
  cp -r "${HOME}/.dotfiles/zsh" "${BACKUP_DIR}/" && echo "  zsh 配置备份完成"
else
  echo "  警告: ~/.dotfiles/zsh 目录不存在，跳过"
fi

# 备份 .zshrc
if [[ -f "${HOME}/.zshrc" ]]; then
  cp "${HOME}/.zshrc" "${BACKUP_DIR}/" && echo "  .zshrc 备份完成"
else
  echo "  警告: ~/.zshrc 不存在，跳过"
fi

# 备份缓存
if [[ -d "${HOME}/.cache/zsh" ]]; then
  cp -r "${HOME}/.cache/zsh" "${BACKUP_DIR}/" 2>/dev/null && echo "  zsh 缓存备份完成" || echo "  警告: 缓存备份失败"
fi

echo "备份完成！"
echo "备份文件：${BACKUP_DIR}"
