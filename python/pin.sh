#!/usr/bin/env bash

# ======================
# Python 版本固化
# ======================
#
# 功能:
#   1. 记录当前 python3 / uv / pip3 版本
#   2. 记录 venv 中已安装的包及版本
#   3. 记录已安装的 CLI 工具及版本
#   4. 写入 versions.lock 文件
#
# 用法:
#   ./pin.sh                  # 固化当前版本到 versions.lock
#   ./pin.sh --restore        # 从 versions.lock 恢复版本
#   ./pin.sh --diff           # 对比当前版本与 versions.lock

set -euo pipefail

# shellcheck source=/dev/null
source "$(dirname "$0")/_common.sh"

LOCK_FILE="${PYTHON_DIR}/versions.lock"
ACTION="pin"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --restore) ACTION="restore"; shift ;;
    --diff)    ACTION="diff"; shift ;;
    -h|--help)
      echo "用法: $(basename "$0") [--restore] [--diff]"
      echo "  （默认）   固化当前版本到 versions.lock"
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
  echo_step "固化当前 Python 版本..."

  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

  {
    echo "# ======================"
    echo "# Python 版本锁定文件"
    echo "# ======================"
    echo "# 生成时间: ${timestamp}"
    echo "# 由 python/pin.sh 自动生成，请勿手动编辑"
    echo ""

    # 核心工具版本
    echo "[core]"
    echo "python3 = $(get_python_version 2>/dev/null || echo 'unknown')"
    echo "uv      = $(uv --version 2>&1 | awk '{print $2}' || echo 'not-installed')"
    echo "pip3    = $(pip3 --version 2>/dev/null | awk '{print $2}' || echo 'not-installed')"
    echo "pipx    = $(pipx --version 2>/dev/null || echo 'not-installed')"
    echo ""

    # venv 中的包
    local venv_dir="${HOME}/.venv-dotfiles"
    if [[ -d "$venv_dir" && -f "${venv_dir}/bin/pip" ]]; then
      echo "[venv-packages]"
      "${venv_dir}/bin/pip" freeze 2>/dev/null | sort | while read -r line; do
        [[ -n "$line" ]] && echo "  ${line}"
      done
      echo ""
    fi

    # CLI 工具版本
    if has_uv; then
      echo "[tools]"
      if uv tool list 2>/dev/null | grep -q '.'; then
        uv tool list 2>/dev/null | while IFS= read -r line; do
          # uv tool list 输出格式: "package-name v1.2.3 - description"
          local name ver
          name="$(echo "$line" | awk '{print $1}')"
          ver="$(echo "$line" | awk '{print $2}' | sed 's/^v//')"
          [[ -n "$name" ]] && echo "  ${name} = ${ver}"
        done
      else
        echo "  # 无已安装的 CLI 工具"
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

  # 恢复 venv 依赖
  local venv_dir="${HOME}/.venv-dotfiles"
  if [[ -d "$venv_dir" ]]; then
    local req_temp
    req_temp="$(mktemp)"
    awk '/^\[venv-packages\]/{flag=1; next} /^\[/{flag=0} flag && /^  /{sub(/^  /,""); print}' "$LOCK_FILE" > "$req_temp"

    if [[ -s "$req_temp" ]]; then
      echo_step "恢复 venv 依赖..."
      if has_uv; then
        uv pip install -r "$req_temp" 2>/dev/null && \
          echo_success "venv 依赖已恢复" || echo_warning "部分依赖恢复失败"
      else
        "${venv_dir}/bin/pip" install -r "$req_temp" 2>/dev/null && \
          echo_success "venv 依赖已恢复" || echo_warning "部分依赖恢复失败"
      fi
    fi
    rm -f "$req_temp"
  fi

  # 恢复 CLI 工具
  local tools_section=false
  while IFS='=' read -r key value || [[ -n "$key" ]]; do
    key="$(echo "$key" | xargs)"
    value="$(echo "$value" | xargs)"

    [[ "$key" == "[tools]" ]] && tools_section=true && continue
    [[ "$key" == "["* ]] && tools_section=false && continue
    [[ "$key" == "#"* || -z "$key" ]] && continue

    if $tools_section && has_uv && [[ -n "$key" ]]; then
      echo_step "安装 ${key}@${value}..."
      if [[ -z "$value" || "$value" == "unknown" ]]; then
        uv tool install "$key" > /dev/null 2>&1 && \
          echo_success "${key} 已安装" || echo_warning "${key} 安装失败"
      else
        uv tool install "$key" --version "$value" > /dev/null 2>&1 && \
          echo_success "${key}@${value} 已安装" || echo_warning "${key}@${value} 安装失败"
      fi
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
  local locked_py current_py
  locked_py="$(grep '^python3' "$LOCK_FILE" | awk -F'= ' '{print $2}')"
  current_py="$(get_python_version 2>/dev/null || echo 'unknown')"

  if [[ "$locked_py" == "$current_py" ]]; then
    echo_success "python3: ${current_py}（一致）"
  else
    echo_warning "python3: ${locked_py} → ${current_py}"
    changed=$((changed + 1))
  fi

  local locked_uv current_uv
  locked_uv="$(grep '^uv ' "$LOCK_FILE" | awk -F'= ' '{print $2}')"
  current_uv="$(uv --version 2>&1 | awk '{print $2}' || echo 'not-installed')"

  if [[ "$locked_uv" == "$current_uv" ]]; then
    echo_success "uv: ${current_uv}（一致）"
  else
    echo_warning "uv: ${locked_uv} → ${current_uv}"
    changed=$((changed + 1))
  fi

  # 对比 CLI 工具
  echo ""
  echo_step "CLI 工具对比:"
  local tools_section=false
  while IFS='=' read -r key value || [[ -n "$key" ]]; do
    key="$(echo "$key" | xargs)"
    value="$(echo "$value" | xargs)"
    [[ "$key" == "[tools]" ]] && tools_section=true && continue
    [[ "$key" == "["* ]] && tools_section=false && continue
    [[ "$key" == "#"* || -z "$key" ]] && continue

    if $tools_section && [[ -n "$key" ]]; then
      local current_ver=""
      if has_uv; then
        current_ver="$(uv tool list 2>/dev/null | awk -v t="$key" '$1==t {gsub(/^v/,"",$2); print $2; exit}')"
      fi
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
  echo_title "Python 版本固化"

  case "$ACTION" in
    pin)     do_pin ;;
    restore) do_restore ;;
    diff)    do_diff ;;
  esac

  echo_separator
}

main
