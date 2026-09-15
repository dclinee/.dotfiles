#!/usr/bin/env bash
# lib/_module_loader.sh — 模块公共加载器（内部文件）
#
# 所有模块的 _common.sh 都应该 source 本文件，而不是自己实现：
#   <MODULE>_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "${<MODULE>_DIR}/.." && pwd)}"
#   source "${DOTFILES_ROOT}/lib/common.sh" || { ... }
#
# 用法（在各模块 _common.sh 顶部）：
#   source "$(dirname "${BASH_SOURCE[0]}")/../lib/_module_loader.sh" "<MODULE>_DIR"
#   has_foo() { has_cmd foo; }  # 模块特有函数
#
# 注意：本文件在顶层被 source（非函数内），因此不使用 local，变量加 _ml_ 前缀避免污染。

# 接收模块目录变量名作为参数（如 "BREW_DIR"、"EMACS_DIR"）
_ml_var_name="${1:-MODULE_DIR}"

# 解析调用者的模块目录（_common.sh 所在目录）
_ml_module_dir="$(cd "$(dirname "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}")" && pwd)"

# 设置调用者请求的变量名（BREW_DIR / EMACS_DIR ...）
eval "${_ml_var_name}='${_ml_module_dir}'"

# 解析 DOTFILES_ROOT（模块目录往上一级即项目根）
DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "${_ml_module_dir}/.." && pwd)}"

# 加载 lib/common.sh（核心函数库）
# shellcheck source=/dev/null
if ! source "${DOTFILES_ROOT}/lib/common.sh"; then
  printf 'ERROR: 无法加载 lib/common.sh (路径: %s)\n' "${DOTFILES_ROOT}/lib/common.sh" >&2
  return 1 2>/dev/null || exit 1
fi
