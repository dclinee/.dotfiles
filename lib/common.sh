#!/usr/bin/env bash
# 本文件由调用者 source，预期调用者已设置 set -euo pipefail

# ======================
# 公共通用函数库
# ======================
#
# 供所有模块脚本复用的通用函数：
#   1. 模块初始化（自动解析 DOTFILES_ROOT + 加载 output/symlink 库及 fallback）
#   2. tools.list 解析
#   3. 体检统计（check_ok/check_warn/check_fail + 结果汇总）
#   4. 软链批量检查 / 批量删除
#   5. 通用小工具（has_cmd / is_dry_run 等）
#
# 依赖顺序: lib/output.sh → lib/symlink.sh → lib/common.sh
# 但 common.sh 自带 fallback，三者都缺失时也可独立工作
#
# 使用方法（模块内 _common.sh 只需要 3 行）:
#   MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "${MODULE_DIR}/.." && pwd)}"
#   source "${DOTFILES_ROOT}/lib/common.sh"
#
# 之后使用:
#   read_tools_list "${MODULE_DIR}/tools.list"
#   check_init; check_ok "xxx"; check_summary

if [[ -z "${__COMMON_SH_LOADED:-}" ]]; then
__COMMON_SH_LOADED=1

# 自动推导 DOTFILES_ROOT（调用方可能只设置了 DOTFILES_DIR，或什么都没设置）
# 防御 set -u: 所有访问均走 :- 兜底
if [[ -z "${DOTFILES_ROOT:-}" ]]; then
  if [[ -n "${DOTFILES_DIR:-}" ]] && [[ -d "${DOTFILES_DIR}/lib" ]]; then
    DOTFILES_ROOT="${DOTFILES_DIR}"
  elif [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    # 根据 lib/common.sh 的位置向上一级
    _cs_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
    if [[ -n "${_cs_dir:-}" ]] && [[ -d "${_cs_dir}/.." ]]; then
      DOTFILES_ROOT="$(cd "${_cs_dir}/.." 2>/dev/null && pwd)"
    fi
  fi
  # 最终兜底
  DOTFILES_ROOT="${DOTFILES_ROOT:-${HOME}/.dotfiles}"
fi

# ======================
# 1. 自动加载依赖库（含 fallback，保证任何时候输出函数都可用）
# ======================
_common_load_libs() {
  # 尝试加载 lib/output.sh
  if [[ -n "${__OUTPUT_SH_LOADED:-}" ]]; then
    return 0
  fi
  local _output_lib="${DOTFILES_ROOT:-${HOME}/.dotfiles}/lib/output.sh"
  if [[ -f "${_output_lib}" ]]; then
    # shellcheck source=/dev/null
    source "${_output_lib}"
    return 0
  fi

  # Fallback: 内联最小化 output 函数（当 lib 缺失时不崩）
  # 注意：此处图标与 lib/output.sh 保持同步（Oh My Zsh 风格）
  if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
    RED="" GREEN="" YELLOW="" BLUE="" CYAN="" RESET="" BOLD=""
  else
    RED="\033[31m"; GREEN="\033[32m"; YELLOW="\033[33m"; BLUE="\033[34m"
    CYAN="\033[36m"; RESET="\033[0m"; BOLD="\033[1m"
  fi
  CHECK="✓"; INFO="➜"; WARN="⚠"; ERROR="✗"; SKIP="⊘"
  # 兼容保留：ARROW/WHITE（旧脚本引用，避免 set -u 崩溃）
  ARROW="${INFO}"
  WHITE=$([[ -z "${NO_COLOR:-}" && -t 1 ]] && printf '\033[37m' || printf '')
  SEPARATOR="${BLUE}============================================${RESET}"
  echo_step()      { printf "${BOLD}${BLUE}${INFO}  %s${RESET}\n"  "${1}"; }
  echo_success()   { printf "${GREEN}${CHECK} %s${RESET}\n"        "${1}"; }
  echo_warning()   { printf "${YELLOW}${WARN}  %s${RESET}\n"        "${1}"; }
  echo_error()     { printf "${RED}${ERROR} %s${RESET}\n"          "${1}"; }
  echo_skip()      { printf "${CYAN}${SKIP} %s${RESET}\n"          "${1}"; }
  echo_detail()    { printf "${BLUE}  %s${RESET}\n"                "${1}"; }
  echo_separator() { printf '%b\n' "${SEPARATOR}"; }
  echo_title() {
    echo_separator
    printf "${BOLD}${CYAN}%s${RESET}\n" "${1}"
    echo_separator
  }
  __OUTPUT_SH_LOADED=1
}

_common_load_symlink() {
  if [[ -n "${__SYMLINK_SH_LOADED:-}" ]]; then
    return 0
  fi
  local _symlink_lib="${DOTFILES_ROOT:-${HOME}/.dotfiles}/lib/symlink.sh"
  if [[ -f "${_symlink_lib}" ]]; then
    # shellcheck source=/dev/null
    source "${_symlink_lib}"
    return 0
  fi

  # Fallback: 内联 safe_symlink 最小化实现
  # 注意：此处与 lib/symlink.sh 保持同步（含 _resolve_link 跨平台兼容）
  _resolve_link() {
    local target="$1"
    if readlink -f "$target" 2>/dev/null; then
      return 0
    fi
    python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$target" 2>/dev/null || echo "$target"
  }
  safe_symlink() {
    local src="$1" dst="$2"
    [[ -e "$src" ]] || { echo_warning "源文件不存在: $src"; return 1; }
    if [[ -L "$dst" ]] && [[ "$(_resolve_link "$dst")" == "$(_resolve_link "$src")" ]]; then
      echo_skip "链接已存在: $dst"; return 0
    fi
    if [[ -e "$dst" ]] || [[ -L "$dst" ]]; then
      local backup="${dst}.bak.$(date +%Y%m%d_%H%M%S 2>/dev/null || echo bak)"
      mv "$dst" "$backup" 2>/dev/null && echo_warning "已备份: $dst → $backup"
    fi
    mkdir -p "$(dirname "$dst")" 2>/dev/null
    ln -sf "$src" "$dst" 2>/dev/null && echo_detail "已链接: $dst → $src" || { echo_error "链接失败: $dst"; return 1; }
  }
  __SYMLINK_SH_LOADED=1
}

# 执行自动加载（在 DOTFILES_ROOT 已定义后立即调用）
_common_load_libs
_common_load_symlink

# ======================
# 2. 通用小工具函数
# ======================

# 判断命令是否存在（比直接写 command -v 可读性更高）
# 用法: has_cmd python3 && echo "已安装"
has_cmd() {
  command -v "$1" > /dev/null 2>&1
}

# 是否为 dry-run 模式（统一判断 DRY_RUN=true）
is_dry_run() {
  [[ "${DRY_RUN:-false}" == "true" ]]
}

# 获取工具版本（兼容 "name --version" 和 "name version" 两种输出格式）
# 用法: get_version rustc → "1.80.0"
get_version() {
  local cmd="$1"
  has_cmd "$cmd" || return 1
  # 优先 --version，失败则 version
  local out
  out=$("$cmd" --version 2>&1 | head -1) || out=$("$cmd" version 2>&1 | head -1)
  echo "$out" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true
}

# ======================
# 3. tools.list 解析器
# ======================
#
# 解析 tools.list，支持 "name|version" 或 "name" 两种格式
# 自动跳过注释行（# 开头）和空行
# 输出: "name version" 对（version 为空时仅输出 name）
#
# 无参数时，按以下顺序查找 tools.list：
#   1. ${RUST_DIR}/tools.list
#   2. ${PYTHON_DIR}/tools.list
#   3. $(pwd)/tools.list
#
# 用法:
#   read_tools_list | while read -r name version; do ...; done
#   read_tools_list /path/to/custom.list | while read -r name version; do ...; done
read_tools_list() {
  local list_file="${1:-}"
  if [[ -z "$list_file" ]]; then
    # 自动探测
    if [[ -n "${RUST_DIR:-}" && -f "${RUST_DIR}/tools.list" ]]; then
      list_file="${RUST_DIR}/tools.list"
    elif [[ -n "${PYTHON_DIR:-}" && -f "${PYTHON_DIR}/tools.list" ]]; then
      list_file="${PYTHON_DIR}/tools.list"
    else
      list_file="$(pwd)/tools.list"
    fi
  fi
  [[ -f "$list_file" ]] || return 1
  while IFS='|' read -r name version || [[ -n "$name" ]]; do
    [[ -z "$name" || "$name" == \#* ]] && continue
    # 修剪首尾空白（使用参数扩展，避免 xargs 处理特殊字符）
    name="${name#"${name%%[![:space:]]*}"}"
    name="${name%"${name##*[![:space:]]}"}"
    version="${version#"${version%%[![:space:]]*}"}"
    version="${version%"${version##*[![:space:]]}"}"
    [[ -n "$name" ]] && echo "$name $version"
  done < "$list_file"
}

# ======================
# 4. 体检统计（check.sh 专用）
# ======================
#
# 使用模式:
#   check_init           # 初始化计数器
#   check_ok "消息"      # +1 通过
#   check_warn "消息"    # +1 警告
#   check_fail "消息"    # +1 失败
#   check_summary        # 打印汇总并根据 FAIL 返回退出码

# 初始化体检计数器（调用 check_ok 等之前必须先调用）
check_init() {
  PASS=0; WARN=0; FAIL=0; SKIP=0
}

# 单条检查：通过 / 警告 / 失败 / 跳过
check_ok()   { echo_success "$1"; PASS=$((PASS + 1)); }
check_warn() { echo_warning "$1"; WARN=$((WARN + 1)); }
check_fail() { echo_error   "$1"; FAIL=$((FAIL + 1)); }
check_skip() { echo_skip "$1"; SKIP=$((SKIP + 1)); }

# 打印体检汇总并退出（FAIL > 0 时 exit 1）
# 注意: 默认行为是 exit 1（在 set -euo pipefail 下会终止整个脚本）
#       传 --no-exit 可仅打印不退出（用于不想中断的调用场景）
# 用法: check_summary [--no-exit]
check_summary() {
  PASS=${PASS:-0}; WARN=${WARN:-0}; FAIL=${FAIL:-0}; SKIP=${SKIP:-0}
  local _no_exit=false
  [[ "${1:-}" == "--no-exit" ]] && _no_exit=true

  echo_title "体检结果"
  printf "${GREEN}✓ 通过: ${PASS}${RESET}  ${YELLOW}⚠ 警告: ${WARN}${RESET}  ${RED}✗ 失败: ${FAIL}${RESET}  ${CYAN}⊘ 跳过: ${SKIP}${RESET}\n"

  if [[ $FAIL -gt 0 ]]; then
    echo ""
    echo_error "存在 ${FAIL} 项失败，建议修复"
    $_no_exit || exit 1
  elif [[ $WARN -gt 0 ]]; then
    echo ""
    echo_warning "存在 ${WARN} 项警告，建议检查"
  else
    echo ""
    echo_success "所有检查项通过"
  fi
  echo_separator
}

# ======================
# 5. 软链批量操作（check.sh + uninstall.sh 复用）
# ======================
#
# configs 数组格式: "目标路径|源路径" 或 "目标路径"（uninstall 时只需目标）
# 示例:
#   local configs=(
#     "${HOME}/.config/uv/uv.toml|${PYTHON_DIR}/uv.toml.template"
#     "${HOME}/.pip/pip.conf|${PYTHON_DIR}/pip.conf"
#   )
#   check_symlinks "${configs[@]}"     # check.sh 用：验证软链是否正确
#   remove_symlinks "${configs[@]}"    # uninstall.sh 用：删除软链

# 跨平台 resolve symlink（macOS BSD readlink 不支持 -f）
# 注意: 若 lib/symlink.sh 或 fallback 已定义则跳过（避免重复定义）
if ! command -v _resolve_link > /dev/null 2>&1; then
  _resolve_link() {
    local target="$1"
    if readlink -f "$target" 2>/dev/null; then
      return 0
    fi
    python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$target" 2>/dev/null || echo "$target"
  }
fi

# 批量检查软链状态（check.sh 专用）
# 对每个 "dst|src"：
#   - 正确链接 → check_ok
#   - 存在但指向不同 → check_warn
#   - 独立文件非软链 → check_warn
#   - 不存在 → check_fail
check_symlinks() {
  local pair dst src target
  for pair in "$@"; do
    dst="${pair%%|*}"
    src="${pair##*|}"
    # 没有 | 分隔时，跳过源校验（只检查存在）
    if [[ "$pair" != *"|"* ]]; then
      src=""
    fi

    if [[ -L "$dst" ]]; then
      target="$(_resolve_link "$dst")"
      if [[ -n "$src" ]] && [[ "$target" == "$(_resolve_link "$src")" ]]; then
        check_ok "软链正确: $(basename "$dst")"
      elif [[ -n "$src" ]]; then
        check_warn "软链指向不同: $(basename "$dst") → ${target}"
      else
        check_ok "软链存在: $(basename "$dst")"
      fi
    elif [[ -e "$dst" ]]; then
      check_warn "存在独立文件（非软链）: $(basename "$dst")"
    else
      check_fail "缺失: $(basename "$dst")"
    fi
  done
}

# 批量删除软链（uninstall.sh 专用）
# 对每个 "dst|src"（src 可省略），仅当 dst 是软链时删除
# 独立文件不会被误删，留备份在原处
remove_symlinks() {
  local pair dst
  for pair in "$@"; do
    dst="${pair%%|*}"
    if [[ -L "$dst" ]]; then
      if is_dry_run; then
        echo_detail "[dry-run] 将删除软链: $dst"
        continue
      fi
      rm -f "$dst" 2>/dev/null
      if [[ ! -e "$dst" ]]; then
        echo_success "已删除软链: $dst"
      else
        echo_warning "删除失败: $dst"
      fi
    elif [[ -e "$dst" ]]; then
      echo_warning "跳过独立文件（非软链）: $dst"
    else
      echo_skip "软链不存在: $dst"
    fi
  done
}

# 批量清理目录（clean.sh 专用）
# 用法: clean_dirs "$HOME/.cache/xxx" "/tmp/yyy" ...
# 每个目录会先 echo 说明，dry-run 时不实际删除
clean_dirs() {
  local d
  for d in "$@"; do
    if [[ ! -e "$d" ]]; then
      echo_skip "不存在: $d"
      continue
    fi
    local count
    count=$(find "$d" -type f 2>/dev/null | wc -l | tr -d ' ')
    echo_step "清理: $d (${count} 个文件)"
    if is_dry_run; then
      echo_detail "[dry-run] 将删除: $d"
      continue
    fi
    rm -rf "$d" 2>/dev/null && echo_success "已清理: $d" || echo_warning "清理失败: $d"
  done
}

fi  # __COMMON_SH_LOADED
