#!/usr/bin/env bash
# 本文件由调用者 source，预期调用者已设置 set -euo pipefail

# ======================
# 公共符号链接函数库
# ======================
#
# 提供 safe_symlink 函数，统一处理符号链接的创建、备份和验证
# 适用于 bash 和 zsh 脚本
#
# 依赖: lib/output.sh 中的 echo_warning / echo_skip / echo_detail / echo_error
#
# 使用方法:
#   source "${DOTFILES_DIR}/lib/symlink.sh"
#   safe_symlink "${DOTFILES_DIR}/zsh/.zshrc" "${HOME}/.zshrc"

if [[ -z "${__SYMLINK_SH_LOADED:-}" ]]; then
  __SYMLINK_SH_LOADED=1

# 跨平台 resolve symlink（macOS BSD readlink 不支持 -f）
_resolve_link() {
  local target="$1"
  # macOS 13.0+ 支持 readlink -f，旧版用 Python 兜底
  if readlink -f "$target" 2>/dev/null; then
    return 0
  fi
  python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$target" 2>/dev/null || echo "$target"
}

# safe_symlink <source> <target>
#
# 统一处理符号链接创建：
#   1. 检查源文件是否存在
#   2. 若目标已是正确链接 → 跳过
#   3. 若目标已存在（文件或错误链接）→ 备份后重建
#   4. 创建链接并验证
#
# 返回值:
#   0 - 链接已存在或创建成功
#   1 - 源文件不存在或链接创建失败
safe_symlink() {
  local src="$1"
  local dst="$2"

  # 1. 检查源文件存在
  if [[ ! -e "$src" ]]; then
    echo_warning "源文件不存在: $src"
    return 1
  fi

  # 2. 已是正确链接 → 跳过
  if [[ -L "$dst" ]] && [[ "$(_resolve_link "$dst")" == "$(_resolve_link "$src")" ]]; then
    echo_skip "链接已存在: $dst"
    return 0
  fi

  # 3. 现有文件/错误链接 → 备份
  if [[ -e "$dst" ]] || [[ -L "$dst" ]]; then
    local backup="${dst}.bak.$(date +%Y%m%d_%H%M%S 2>/dev/null || echo bak)"
    if mv "$dst" "$backup" 2>/dev/null; then
      echo_warning "已备份: $dst → $backup"
    else
      echo_warning "无法备份，尝试直接删除: $dst"
      rm -f "$dst" 2>/dev/null
    fi
  fi

  # 4. 创建目录 + 链接 + 验证
  mkdir -p "$(dirname "$dst")" 2>/dev/null
  if ln -sf "$src" "$dst" 2>/dev/null; then
    echo_detail "已链接: $dst → $src"
    return 0
  else
    echo_error "链接失败: $dst"
    return 1
  fi
}

fi  # __SYMLINK_SH_LOADED
