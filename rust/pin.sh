#!/usr/bin/env bash

# ======================
# Rust 版本固化
# ======================
#
# 功能:
#   1. 记录当前 rustc / cargo / rustup 版本
#   2. 记录已安装 cargo 工具及版本
#   3. 记录默认工具链和组件列表
#   4. 写入 versions.lock 文件
#
# 用法:
#   ./pin.sh                  # 固化当前版本到 versions.lock
#   ./pin.sh --restore        # 从 versions.lock 恢复版本
#   ./pin.sh --diff           # 对比当前版本与 versions.lock

set -euo pipefail

# shellcheck source=/dev/null
source "$(dirname "$0")/_common.sh"

LOCK_FILE="${RUST_DIR}/versions.lock"
ACTION="pin"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --restore) ACTION="restore"; shift ;;
    --diff)    ACTION="diff"; shift ;;
    -h|--help)
      echo "用法: $(basename "$0") [--restore] [--diff]"
      echo "  （默认）  固化当前版本到 versions.lock"
      echo "  --restore  从 versions.lock 恢复版本"
      echo "  --diff     对比当前版本与 versions.lock"
      exit 0 ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done

# ======================
# 固化版本
# ======================
do_pin() {
  echo_step "固化当前 Rust 版本..."

  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

  {
    echo "# ======================"
    echo "# Rust 版本锁定文件"
    echo "# ======================"
    echo "# 生成时间: ${timestamp}"
    echo "# 由 rust/pin.sh 自动生成，请勿手动编辑"
    echo ""

    # 核心工具版本
    echo "[core]"
    echo "rustup = $(rustup --version 2>&1 | head -1 | awk '{print $2}')"
    echo "rustc  = $(rustc --version 2>/dev/null | awk '{print $2}')"
    echo "cargo  = $(cargo --version 2>/dev/null | awk '{print $2}')"
    echo ""

    # 默认工具链
    if has_rustup; then
      echo "[toolchain]"
      echo "default = $(rustup default 2>/dev/null | awk '{print $1}')"
      echo "installed = $(rustup toolchain list 2>/dev/null | tr '\n' ' ')"
      echo ""

      # 组件列表
      echo "[components]"
      rustup component list 2>/dev/null | grep 'installed$' | sed 's/ .*//' | while read -r comp; do
        echo "  ${comp}"
      done
      echo ""
    fi

    # cargo 工具版本
    if has_cargo; then
      echo "[tools]"
      if cargo install --list 2>/dev/null | grep -E '^[a-z]'; then
        cargo install --list 2>/dev/null | awk '
          /^[a-z]/ { name=$1 }
          /version:/ { ver=$3; gsub(/"/, "", ver); print "  "name" = "ver }
        '
      else
        echo "  # 无已安装的 cargo 工具"
      fi
    fi
  } > "$LOCK_FILE"

  echo_success "版本已固化到: ${LOCK_FILE}"
  echo ""
  echo_detail "文件内容预览:"
  head -20 "$LOCK_FILE"
}

# ======================
# 恢复版本
# ======================
do_restore() {
  if [[ ! -f "$LOCK_FILE" ]]; then
    echo_error "版本锁定文件不存在: ${LOCK_FILE}"
    echo "  先运行: ./pin.sh"
    exit 1
  fi

  echo_step "从 versions.lock 恢复版本..."

  # 解析并恢复工具链
  local target_rustc
  target_rustc="$(grep '^rustc' "$LOCK_FILE" 2>/dev/null | awk -F'= ' '{print $2}')"

  if has_rustup && [[ -n "$target_rustc" ]]; then
    echo_step "安装工具链 ${target_rustc}..."
    rustup toolchain install "${target_rustc}" 2>/dev/null || \
      echo_warning "无法安装工具链 ${target_rustc}"
  fi

  # 恢复工具
  local tools_section=false
  while IFS='=' read -r key value || [[ -n "$key" ]]; do
    key="$(echo "$key" | xargs)"
    value="$(echo "$value" | xargs)"

    [[ "$key" == "[tools]" ]] && tools_section=true && continue
    [[ "$key" == "["* ]] && tools_section=false && continue
    [[ "$key" == "#"* || -z "$key" ]] && continue

    if $tools_section && has_cargo && [[ -n "$key" && -n "$value" ]]; then
      echo_step "安装 ${key}@${value}..."
      cargo install "$key" --version "$value" --force > /dev/null 2>&1 && \
        echo_success "${key}@${value} 已安装" || \
        echo_warning "${key}@${value} 安装失败"
    fi
  done < "$LOCK_FILE"

  echo_success "版本恢复完成"
}

# ======================
# 对比版本
# ======================
do_diff() {
  if [[ ! -f "$LOCK_FILE" ]]; then
    echo_error "版本锁定文件不存在: ${LOCK_FILE}"
    exit 1
  fi

  echo_step "对比当前版本与 versions.lock..."
  echo ""

  local changed=0

  # 对比核心版本
  local locked_rustc current_rustc
  locked_rustc="$(grep '^rustc' "$LOCK_FILE" | awk -F'= ' '{print $2}')"
  current_rustc="$(rustc --version 2>/dev/null | awk '{print $2}')"

  if [[ "$locked_rustc" == "$current_rustc" ]]; then
    echo_success "rustc: ${current_rustc}（一致）"
  else
    echo_warning "rustc: ${locked_rustc} → ${current_rustc}"
    changed=$((changed + 1))
  fi

  local locked_cargo current_cargo
  locked_cargo="$(grep '^cargo' "$LOCK_FILE" | awk -F'= ' '{print $2}')"
  current_cargo="$(cargo --version 2>/dev/null | awk '{print $2}')"

  if [[ "$locked_cargo" == "$current_cargo" ]]; then
    echo_success "cargo: ${current_cargo}（一致）"
  else
    echo_warning "cargo: ${locked_cargo} → ${current_cargo}"
    changed=$((changed + 1))
  fi

  # 对比工具
  echo ""
  echo_step "cargo 工具对比:"
  local tools_section=false
  while IFS='=' read -r key value || [[ -n "$key" ]]; do
    key="$(echo "$key" | xargs)"
    value="$(echo "$value" | xargs)"
    [[ "$key" == "[tools]" ]] && tools_section=true && continue
    [[ "$key" == "["* ]] && tools_section=false && continue
    [[ "$key" == "#"* || -z "$key" ]] && continue

    if $tools_section && [[ -n "$key" ]]; then
      local current_ver
      current_ver="$(cargo install --list 2>/dev/null | awk -v t="$key" '$1==t {found=1} found && /version:/ {print $3; gsub(/"/,""); exit}' | tr -d '"')"
      if [[ -z "$current_ver" ]]; then
        echo_warning "  ${key}: ${value} → 未安装"
        changed=$((changed + 1))
      elif [[ "$value" == "$current_ver" ]]; then
        echo_success "  ${key}: ${value}（一致）"
      else
        echo_warning "  ${key}: ${value} → ${current_ver}"
        changed=$((changed + 1))
      fi
    fi
  done < "$LOCK_FILE"

  echo ""
  if [[ $changed -eq 0 ]]; then
    echo_success "所有版本一致"
  else
    echo_warning "发现 ${changed} 项差异"
  fi
}

# ======================
# 主流程
# ======================
main() {
  echo_title "Rust 版本固化"

  case "$ACTION" in
    pin)     do_pin ;;
    restore) do_restore ;;
    diff)    do_diff ;;
  esac

  echo_separator
}

main
