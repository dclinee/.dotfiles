#!/usr/bin/env bash
# Zsh 配置备份脚本

BACKUP_DIR="${HOME}/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "${BACKUP_DIR}"

echo "正在备份 Zsh 配置到 ${BACKUP_DIR}..."

# 备份核心配置
cp -r "${HOME}/.dotfiles/zsh" "${BACKUP_DIR}/"
cp "${HOME}/.zshrc" "${BACKUP_DIR}/"
cp -r "${HOME}/.cache/zsh" "${BACKUP_DIR}/" 2>/dev/null || true

echo "备份完成！"
echo "备份文件：${BACKUP_DIR}"
