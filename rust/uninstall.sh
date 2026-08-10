#!/usr/bin/env bash

# ======================
# Rust 配置卸载器
# ======================
#
# 功能:
#   1. 移除配置文件软链（~/.cargo/config.toml、~/.rustfmt.toml、~/.clippy.toml）
#   2. 清理 shell 配置中的 cargo/env 引用
#   3. 可选: 卸载 cargo 工具（--tools）
#   4. 可选: 完全卸载 rustup（--purge）
#
# 用法:
#   ./uninstall.sh             # 仅移除配置软链和环境变量
#   ./uninstall.sh --tools     # 额外卸载 cargo 扩展工具
#   ./uninstall.sh --purge     # 彻底卸载 rustup + 工具链（需确认）

set -euo pipefail

# shellcheck source=/dev/null
source "$(dirname "$0")/_common.sh"

PURGE=false
REMOVE_TOOLS=false

# 解析参数
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tools)  REMOVE_TOOLS=true; shift ;;
    --purge)  PURGE=true; shift ;;
    -h|--help)
      echo "用法: $(basename "$0") [--tools] [--purge]"
      echo "  --tools  额外卸载 cargo 扩展工具"
      echo "  --purge  彻底卸载 rustup + 工具链（需确认）"
      exit 0 ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done

# ======================
# 移除配置软链
# ======================
remove_symlinks() {
  echo_step "移除 Rust 配置软链..."

  local configs=(
    "${HOME}/.cargo/config.toml"
    "${HOME}/.rustfmt.toml"
    "${HOME}/.clippy.toml"
  )

  for cfg in "${configs[@]}"; do
    if [[ -L "$cfg" ]]; then
      rm -f "$cfg"
      echo_success "已移除软链: ${cfg}"
    elif [[ -f "$cfg" ]]; then
      echo_warning "存在非软链文件，跳过: ${cfg}"
    else
      echo_skip "不存在: ${cfg}"
    fi
  done
}

# ======================
# 清理环境变量
# ======================
cleanup_env() {
  echo_step "清理 shell 配置中的 cargo/env 引用..."

  local files=("${HOME}/.zshrc" "${HOME}/.zshenv" "${HOME}/.zshrc.local" "${HOME}/.bashrc")
  local cleaned=0

  for f in "${files[@]}"; do
    [[ ! -f "$f" ]] && continue
    if grep -q '\.cargo/env' "$f" 2>/dev/null; then
      local tmp_file
      tmp_file="$(mktemp)"
      grep -v '\.cargo/env' "$f" | grep -v '# Rust/cargo 环境' > "$tmp_file" 2>/dev/null || true
      mv "$tmp_file" "$f" 2>/dev/null || cp "$tmp_file" "$f" 2>/dev/null
      rm -f "$tmp_file"
      echo_success "已清理: ${f}"
      cleaned=$((cleaned + 1))
    fi
  done

  [[ $cleaned -eq 0 ]] && echo_skip "未发现 cargo/env 引用"
}

# ======================
# 卸载 cargo 扩展工具
# ======================
remove_tools() {
  if ! has_cargo; then
    echo_warning "cargo 不可用，跳过工具卸载"
    return 0
  fi

  echo_step "卸载 cargo 扩展工具..."

  if ! read_tools_list > /dev/null 2>&1; then
    echo_warning "tools.list 不存在，跳过"
    return 0
  fi

  while read -r name version; do
    [[ -z "$name" ]] && continue
    if cargo uninstall "$name" > /dev/null 2>&1; then
      echo_success "已卸载: ${name}"
    else
      echo_skip "未安装或无法卸载: ${name}"
    fi
  done < <(read_tools_list)
}

# ======================
# 彻底卸载 rustup
# ======================
purge_rustup() {
  if ! has_rustup; then
    echo_warning "rustup 未安装，无需卸载"
    return 0
  fi

  echo_warning "即将彻底卸载 rustup 及所有工具链！"
  echo "  这将删除 ~/.rustup 和 ~/.cargo 目录"
  echo ""
  printf "确认卸载? (输入 yes 继续): "
  read -r confirm
  if [[ "$confirm" != "yes" ]]; then
    echo_skip "已取消卸载"
    return 0
  fi

  echo_step "卸载 rustup..."
  rustup self uninstall -y 2>/dev/null || {
    echo_warning "rustup self uninstall 失败，手动清理..."
    rm -rf "${HOME}/.rustup" "${HOME}/.cargo"
  }
  echo_success "rustup 已彻底卸载"
}

# ======================
# 主流程
# ======================
main() {
  echo_title "Rust 配置卸载器"

  remove_symlinks
  echo_separator
  cleanup_env

  if $REMOVE_TOOLS; then
    echo_separator
    remove_tools
  fi

  if $PURGE; then
    echo_separator
    purge_rustup
  fi

  echo_title "卸载完成"
  printf "${GREEN}${CHECK} Rust 配置已移除${RESET}\n"
  if ! $PURGE; then
    echo ""
    echo "提示: Rust 工具链本身未被移除"
    echo "  彻底卸载: ./uninstall.sh --purge"
  fi
  echo_separator
}

main
