#!/usr/bin/env bash
# .editorconfig 配置安装器（极简：只有一个软链）
set -euo pipefail
source "$(dirname "$0")/_common.sh"
safe_symlink "${DOTFILES_ROOT}/.editorconfig" "${HOME}/.editorconfig" || true
