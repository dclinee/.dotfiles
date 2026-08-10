#!/usr/bin/env bash

# ======================
# Rust 一键升级
# ======================
#
# 功能:
#   1. 升级 rustup 自身
#   2. 更新 Rust 工具链（stable）
#   3. 更新所有 cargo 扩展工具（读取 tools.list）
#
# 用法:
#   ./upgrade.sh              # 升级全部
#   ./upgrade.sh --toolchain  # 仅升级工具链
#   ./upgrade.sh --tools      # 仅升级 cargo 工具

set -euo pipefail

# shellcheck source=/dev/null
source "$(dirname "$0")/_common.sh"

UPGRADE_TOOLCHAIN=true
UPGRADE_TOOLS=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --toolchain) UPGRADE_TOOLS=false; shift ;;
    --tools)     UPGRADE_TOOLCHAIN=false; shift ;;
    -h|--help)
      echo "用法: $(basename "$0") [--toolchain] [--tools]"
      echo "  --toolchain  仅升级 Rust 工具链"
      echo "  --tools      仅升级 cargo 扩展工具"
      exit 0 ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done

# ======================
# 升级 rustup + 工具链
# ======================
upgrade_toolchain() {
  if ! has_rustup; then
    echo_warning "rustup 不可用，跳过工具链升级"
    return 0
  fi

  echo_step "升级 rustup 自身..."
  if rustup self update 2>/dev/null; then
    echo_success "rustup 已更新"
  else
    echo_warning "rustup 自更新失败（可能是 Homebrew 安装）"
  fi

  echo_step "更新 Rust 工具链..."
  local old_version
  old_version="$(rustc --version 2>/dev/null || echo '未安装')"

  rustup update stable 2>/dev/null

  local new_version
  new_version="$(rustc --version 2>/dev/null || echo '未知')"

  if [[ "$old_version" == "$new_version" ]]; then
    echo_skip "工具链已是最新: ${new_version}"
  else
    echo_success "工具链已更新: ${old_version} → ${new_version}"
  fi
}

# ======================
# 升级 cargo 工具
# ======================
upgrade_tools() {
  if ! has_cargo; then
    echo_warning "cargo 不可用，跳过工具升级"
    return 0
  fi

  echo_step "升级 cargo 扩展工具..."

  if ! read_tools_list > /dev/null 2>&1; then
    echo_warning "tools.list 不存在，跳过"
    return 0
  fi

  local count=0
  local updated=0
  local skipped=0

  while read -r name version; do
    [[ -z "$name" ]] && continue
    count=$((count + 1))

    printf "${BOLD}${CYAN}${ARROW} 升级 %s...${RESET}\n" "${name}"
    if cargo install "${name}" --locked --force > /dev/null 2>&1; then
      echo_success "${name} 已更新"
      updated=$((updated + 1))
    else
      echo_warning "${name} 升级失败"
      skipped=$((skipped + 1))
    fi
  done < <(read_tools_list)

  echo ""
  echo_success "升级完成: ${updated} 更新 / ${skipped} 失败 / ${count} 总计"
}

# ======================
# 主流程
# ======================
main() {
  echo_title "Rust 一键升级"

  if $UPGRADE_TOOLCHAIN; then
    upgrade_toolchain
    echo_separator
  fi

  if $UPGRADE_TOOLS; then
    upgrade_tools
    echo_separator
  fi

  echo_title "升级完成"
  if has_rustup; then
    printf "${BOLD}当前版本:${RESET}\n"
    echo "  $(rustc --version 2>/dev/null || echo 'rustc 不可用')"
    echo "  $(cargo --version 2>/dev/null || echo 'cargo 不可用')"
    echo ""
  fi
  echo_separator
}

main
