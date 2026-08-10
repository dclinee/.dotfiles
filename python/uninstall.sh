#!/usr/bin/env bash

# ======================
# Python 配置卸载器
# ======================
#
# 功能:
#   1. 移除配置文件软链（~/.config/uv/uv.toml、~/.pip/pip.conf、~/.pythonrc.py）
#   2. 清理 shell 配置中的 dotfiles-py-path 引用
#   3. 可选: 卸载 CLI 工具（--tools）
#   4. 可选: 删除 venv（--venv）
#   5. 可选: 完全卸载 uv（--purge）
#
# 用法:
#   ./uninstall.sh             # 仅移除配置软链
#   ./uninstall.sh --tools     # 额外卸载 CLI 工具
#   ./uninstall.sh --venv      # 额外删除 venv
#   ./uninstall.sh --purge     # 彻底卸载 uv（需确认）

set -euo pipefail

# shellcheck source=/dev/null
source "$(dirname "$0")/_common.sh"

PURGE=false
REMOVE_TOOLS=false
REMOVE_VENV=false

# 解析参数
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tools)  REMOVE_TOOLS=true; shift ;;
    --venv)   REMOVE_VENV=true; shift ;;
    --purge)  PURGE=true; shift ;;
    -h|--help)
      echo "用法: $(basename "$0") [--tools] [--venv] [--purge]"
      echo "  --tools  额外卸载 CLI 工具"
      echo "  --venv   额外删除 venv (~/.venv-dotfiles)"
      echo "  --purge  彻底卸载 uv（需确认）"
      exit 0 ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done

# ======================
# 移除配置软链（复用 lib/common.sh 中的 remove_symlinks）
# ======================
remove_symlinks_local() {
  echo_step "移除 Python 配置软链..."

  local configs=(
    "${HOME}/.config/uv/uv.toml|${PYTHON_DIR}/uv.toml.template"
    "${HOME}/.pip/pip.conf|${PYTHON_DIR}/pip.conf"
    "${HOME}/.pythonrc.py|${PYTHON_DIR}/pythonrc.py"
    "${HOME}/.pyproject.toml|${PYTHON_DIR}/pyproject.toml.template"
  )

  remove_symlinks "${configs[@]}"

  # 移除 PATH 标记文件
  local marker="${HOME}/.local/share/dotfiles-py-path"
  if [[ -f "$marker" ]]; then
    if is_dry_run; then
      echo_detail "[dry-run] 将删除 PATH 标记: ${marker}"
    else
      rm -f "$marker"
      echo_success "已移除 PATH 标记: ${marker}"
    fi
  fi
}

# ======================
# 清理 shell 配置
# ======================
cleanup_shell() {
  echo_step "清理 shell 配置中的 dotfiles-py-path 引用..."

  local files=("${HOME}/.zshrc" "${HOME}/.zshenv" "${HOME}/.zshrc.local" "${HOME}/.bashrc")
  local cleaned=0

  for f in "${files[@]}"; do
    [[ ! -f "$f" ]] && continue
    if grep -q 'dotfiles-py-path' "$f" 2>/dev/null; then
      local tmp_file
      tmp_file="$(mktemp)"
      grep -v 'dotfiles-py-path' "$f" | grep -v '# Dotfiles Python venv' > "$tmp_file" 2>/dev/null || true
      mv "$tmp_file" "$f" 2>/dev/null || cp "$tmp_file" "$f" 2>/dev/null
      rm -f "$tmp_file"
      echo_success "已清理: ${f}"
      cleaned=$((cleaned + 1))
    fi
  done

  [[ $cleaned -eq 0 ]] && echo_skip "未发现 dotfiles-py-path 引用"
}

# ======================
# 卸载 CLI 工具
# ======================
remove_tools() {
  if ! has_uv && ! has_pipx; then
    echo_warning "uv 和 pipx 均不可用，跳过工具卸载"
    return 0
  fi

  echo_step "卸载 CLI 工具..."

  if ! read_tools_list > /dev/null 2>&1; then
    echo_warning "tools.list 不存在，跳过"
    return 0
  fi

  while read -r name version; do
    [[ -z "$name" ]] && continue
    local removed=false

    if has_uv; then
      if uv tool uninstall "$name" > /dev/null 2>&1; then
        echo_success "已卸载（uv）: ${name}"
        removed=true
      fi
    fi

    if ! $removed && has_pipx; then
      if pipx uninstall "$name" > /dev/null 2>&1; then
        echo_success "已卸载（pipx）: ${name}"
        removed=true
      fi
    fi

    $removed || echo_skip "未安装或无法卸载: ${name}"
  done < <(read_tools_list)
}

# ======================
# 删除 venv
# ======================
remove_venv() {
  local venv_dir="${HOME}/.venv-dotfiles"
  if [[ ! -d "$venv_dir" ]]; then
    echo_skip "venv 不存在: ${venv_dir}"
    return 0
  fi

  local size
  size="$(du -sh "$venv_dir" 2>/dev/null | awk '{print $1}')"
  echo_warning "即将删除 venv: ${venv_dir}（大小: ${size}）"

  printf "确认删除? (输入 yes 继续): "
  read -r confirm
  if [[ "$confirm" != "yes" ]]; then
    echo_skip "已取消删除"
    return 0
  fi

  rm -rf "$venv_dir"
  echo_success "venv 已删除"
}

# ======================
# 彻底卸载 uv
# ======================
purge_uv() {
  if ! has_uv; then
    echo_warning "uv 未安装，无需卸载"
    return 0
  fi

  echo_warning "即将彻底卸载 uv！"
  echo "  这将删除 ~/.local/bin/uv 和 ~/.local/share/uv 目录"
  echo ""
  printf "确认卸载? (输入 yes 继续): "
  read -r confirm
  if [[ "$confirm" != "yes" ]]; then
    echo_skip "已取消卸载"
    return 0
  fi

  echo_step "卸载 uv..."
  local uv_bin
  uv_bin="$(command -v uv 2>/dev/null || echo "${HOME}/.local/bin/uv")"

  # 尝试通过官方卸载方式
  if [[ -f "${HOME}/.local/bin/uv" ]]; then
    rm -f "${HOME}/.local/bin/uv" "${HOME}/.local/bin/uvx"
  fi

  # 清理 uv 数据目录
  rm -rf "${HOME}/.local/share/uv" 2>/dev/null || true
  rm -rf "${HOME}/.cache/uv" 2>/dev/null || true
  rm -rf "${HOME}/.config/uv" 2>/dev/null || true

  echo_success "uv 已彻底卸载"
}

# ======================
# 主流程
# ======================
main() {
  echo_title "Python 配置卸载器"

  remove_symlinks_local
  echo_separator
  cleanup_shell

  if $REMOVE_TOOLS; then
    echo_separator
    remove_tools
  fi

  if $REMOVE_VENV; then
    echo_separator
    remove_venv
  fi

  if $PURGE; then
    echo_separator
    purge_uv
  fi

  echo_title "卸载完成"
  printf "${GREEN}${CHECK} Python 配置已移除${RESET}\n"
  if ! $PURGE; then
    echo ""
    echo "提示: uv 本身未被移除"
    echo "  彻底卸载: ./uninstall.sh --purge"
  fi
  echo_separator
}

main
