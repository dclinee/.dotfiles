#!/usr/bin/env bash

# ======================
# Rust 环境体检
# ======================
#
# 功能:
#   1. 检查 rustup / rustc / cargo 版本
#   2. 验证镜像源配置
#   3. 检查组件安装状态
#   4. 检查 cargo 工具安装状态
#   5. 检查配置文件软链
#   6. 权限排查

set -euo pipefail

# shellcheck source=/dev/null
source "$(dirname "$0")/_common.sh"

# 初始化体检计数器
check_init

# ======================
# 检查核心工具
# ======================
check_core_tools() {
  echo_step "核心工具"

  if has_rustup; then
    check_ok "rustup: $(rustup --version 2>&1 | head -1)"
  elif has_rustc && has_cargo; then
    local rust_provider
    rust_provider="$(command -v rustc)"
    if [[ "$rust_provider" == *"/linuxbrew/"* ]] || [[ "$rust_provider" == *"/homebrew/"* ]]; then
      check_ok "rustup: 未安装（当前使用 Homebrew 模式，功能正常）"
    else
      check_warn "rustup: 未安装（使用其他安装方式，建议迁移到 rustup）"
    fi
  else
    check_fail "rustup: 未安装，且未检测到 rustc/cargo"
  fi

  if has_rustc; then
    check_ok "rustc: $(rustc --version)"
  else
    check_fail "rustc: 未安装"
  fi

  if has_cargo; then
    check_ok "cargo: $(cargo --version)"
  else
    check_fail "cargo: 未安装"
  fi
}

# ======================
# 检查工具链与组件
# ======================
check_toolchain() {
  echo_step "工具链与组件"

  if ! has_rustup; then
    check_ok "rustup 不可用，跳过组件检查（Homebrew 模式）"
    return 0
  fi

  local default_toolchain
  default_toolchain="$(rustup default 2>/dev/null | awk '{print $1}')"
  check_ok "默认工具链: ${default_toolchain:-未知}"

  local components=("rustfmt" "clippy" "rust-src")
  for comp in "${components[@]}"; do
    if rustup component list 2>/dev/null | grep -q "^${comp}.*installed"; then
      check_ok "组件已安装: ${comp}"
    else
      check_warn "组件未安装: ${comp}"
    fi
  done
}

# ======================
# 检查镜像源配置
# ======================
check_mirror() {
  echo_step "镜像源配置"

  local cargo_config="${HOME}/.cargo/config.toml"
  if [[ ! -f "$cargo_config" ]]; then
    check_warn "~/.cargo/config.toml 不存在"
    return 0
  fi

  if grep -q 'replace-with' "$cargo_config" 2>/dev/null; then
    local mirror
    mirror="$(grep 'replace-with' "$cargo_config" | head -1 | sed 's/.*= *"\(.*\)"/\1/')"
    check_ok "镜像源: ${mirror}"
  else
    check_warn "未配置镜像源（使用默认 crates.io）"
  fi

  if grep -q 'sparse+' "$cargo_config" 2>/dev/null; then
    check_ok "使用 sparse 协议（更快）"
  fi
}

# ======================
# 检查配置文件软链（复用 check_symlinks）
# ======================
check_configs() {
  echo_step "配置文件软链"

  local configs=(
    "${HOME}/.cargo/config.toml|${RUST_DIR}/cargo_config.toml.template"
    "${HOME}/.rustfmt.toml|${RUST_DIR}/rustfmt.toml"
    "${HOME}/.clippy.toml|${RUST_DIR}/clippy.toml"
  )

  check_symlinks "${configs[@]}"
}

# ======================
# 检查 cargo 工具
# ======================
check_tools() {
  echo_step "cargo 扩展工具"

  if ! has_cargo; then
    check_warn "cargo 不可用，跳过"
    return 0
  fi

  if ! read_tools_list > /dev/null 2>&1; then
    check_warn "tools.list 不存在"
    return 0
  fi

  while read -r name version; do
    [[ -z "$name" ]] && continue
    if command -v "${name}" > /dev/null 2>&1 || cargo install --list 2>/dev/null | grep -q "^${name}"; then
      check_ok "已安装: ${name}"
    else
      check_warn "未安装: ${name}"
    fi
  done < <(read_tools_list)
}

# ======================
# 权限排查
# ======================
check_permissions() {
  echo_step "权限排查"

  local cargo_dir="${HOME}/.cargo"
  local rustup_dir="${HOME}/.rustup"

  for d in "$cargo_dir" "$rustup_dir"; do
    if [[ -d "$d" ]]; then
      local owner
      owner="$(stat -c '%U' "$d" 2>/dev/null || stat -f '%Su' "$d" 2>/dev/null || echo '?')"
      if [[ "$owner" == "$(whoami)" ]]; then
        check_ok "$(basename "$d") 权限正常（owner: ${owner}）"
      else
        check_fail "$(basename "$d") 属主异常: ${owner}（应为 $(whoami)）"
      fi
    fi
  done

  if has_cargo; then
    local cargo_path
    cargo_path="$(command -v cargo)"
    if [[ "$cargo_path" == "${HOME}/.cargo/bin/cargo" ]]; then
      check_ok "cargo 路径: rustup 模式"
    elif [[ "$cargo_path" == *"/linuxbrew/"* ]] || [[ "$cargo_path" == *"/homebrew/"* ]]; then
      check_ok "cargo 路径: Homebrew 模式"
    else
      check_warn "cargo 路径: ${cargo_path}"
    fi
  fi
}

# ======================
# 主流程
# ======================
main() {
  echo_title "Rust 环境体检"

  check_core_tools;    echo_separator
  check_toolchain;     echo_separator
  check_mirror;        echo_separator
  check_configs;       echo_separator
  check_tools;         echo_separator
  check_permissions

  # 复用 check_summary（内部会根据 FAIL 决定是否 exit 1）
  check_summary
}

main
