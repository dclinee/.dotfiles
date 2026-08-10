#!/usr/bin/env bash

# ======================
# Python 一键升级
# ======================
#
# 功能:
#   1. 升级 uv 自身
#   2. 更新 venv 中的依赖（pip install --upgrade）
#   3. 更新所有 CLI 工具（读取 tools.list）
#
# 用法:
#   ./upgrade.sh              # 升级全部
#   ./upgrade.sh --self       # 仅升级 uv 自身
#   ./upgrade.sh --deps       # 仅升级 venv 依赖
#   ./upgrade.sh --tools      # 仅升级 CLI 工具

set -euo pipefail

# shellcheck source=/dev/null
source "$(dirname "$0")/_common.sh"

UPGRADE_SELF=true
UPGRADE_DEPS=true
UPGRADE_TOOLS=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --self)  UPGRADE_DEPS=false; UPGRADE_TOOLS=false; shift ;;
    --deps)  UPGRADE_SELF=false; UPGRADE_TOOLS=false; shift ;;
    --tools) UPGRADE_SELF=false; UPGRADE_DEPS=false; shift ;;
    -h|--help)
      echo "用法: $(basename "$0") [--self] [--deps] [--tools]"
      echo "  --self   仅升级 uv 自身"
      echo "  --deps   仅升级 venv 依赖"
      echo "  --tools  仅升级 CLI 工具"
      exit 0 ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done

# ======================
# 升级 uv 自身
# ======================
upgrade_self() {
  if ! has_uv; then
    echo_warning "uv 不可用，跳过"
    return 0
  fi

  echo_step "升级 uv 自身..."
  local old_version
  old_version="$(uv --version 2>/dev/null || echo '未安装')"

  if uv self update 2>/dev/null; then
    local new_version
    new_version="$(uv --version 2>/dev/null || echo '未知')"
    if [[ "$old_version" == "$new_version" ]]; then
      echo_skip "uv 已是最新: ${new_version}"
    else
      echo_success "uv 已更新: ${old_version} → ${new_version}"
    fi
  else
    echo_warning "uv 自更新失败（可能是 Homebrew 安装，请 brew upgrade uv）"
  fi
}

# ======================
# 升级 venv 依赖
# ======================
upgrade_deps() {
  local venv_dir="${HOME}/.venv-dotfiles"
  if [[ ! -d "$venv_dir" ]]; then
    echo_warning "venv 不存在: ${venv_dir}，跳过"
    return 0
  fi

  echo_step "升级 venv 依赖..."

  local req_file="${PYTHON_DIR}/requirements.txt"
  if [[ ! -f "$req_file" ]]; then
    echo_warning "requirements.txt 不存在，跳过"
    return 0
  fi

  local pip_cmd="${venv_dir}/bin/pip"
  if has_uv; then
    echo_detail "使用 uv 升级..."
    if uv pip install --upgrade -r "$req_file" 2>/dev/null; then
      echo_success "venv 依赖已升级"
    else
      echo_warning "uv pip upgrade 失败，尝试 pip"
      "$pip_cmd" install --upgrade -r "$req_file" 2>/dev/null && \
        echo_success "venv 依赖已升级" || echo_warning "升级失败"
    fi
  else
    "$pip_cmd" install --upgrade -r "$req_file" 2>/dev/null && \
      echo_success "venv 依赖已升级" || echo_warning "升级失败"
  fi
}

# ======================
# 升级 CLI 工具
# ======================
upgrade_tools() {
  if ! has_uv && ! has_pipx; then
    echo_warning "uv 和 pipx 均不可用，跳过工具升级"
    return 0
  fi

  echo_step "升级 CLI 工具..."

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
    if has_uv; then
      if uv tool upgrade "$name" > /dev/null 2>&1; then
        echo_success "${name} 已更新"
        updated=$((updated + 1))
      else
        echo_warning "${name} 升级失败或未安装"
        skipped=$((skipped + 1))
      fi
    elif has_pipx; then
      if pipx upgrade "$name" > /dev/null 2>&1; then
        echo_success "${name} 已更新"
        updated=$((updated + 1))
      else
        echo_warning "${name} 升级失败或未安装"
        skipped=$((skipped + 1))
      fi
    fi
  done < <(read_tools_list)

  echo ""
  echo_success "升级完成: ${updated} 更新 / ${skipped} 失败 / ${count} 总计"
}

# ======================
# 主流程
# ======================
main() {
  echo_title "Python 一键升级"

  if $UPGRADE_SELF; then
    upgrade_self
    echo_separator
  fi

  if $UPGRADE_DEPS; then
    upgrade_deps
    echo_separator
  fi

  if $UPGRADE_TOOLS; then
    upgrade_tools
    echo_separator
  fi

  echo_title "升级完成"
  if has_python3; then
    printf "${BOLD}当前版本:${RESET}\n"
    echo "  python3: $(python3 --version 2>/dev/null || echo '不可用')"
    echo "  uv:      $(uv --version 2>/dev/null || echo '不可用')"
    echo ""
  fi
  echo_separator
}

main
