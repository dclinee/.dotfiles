#!/usr/bin/env bash

# ======================
# Tmux 配置安装器
# ======================

set -euo pipefail
LOG_FILE="/tmp/dotfiles_install_$(date +%Y%m%d_%H%M%S).log"

# shellcheck source=/dev/null
source "$(dirname "$0")/_common.sh"

TMUX_HOME="${TMUX_DIR}"


install_tmux_binary() {
  if command -v tmux > /dev/null 2>&1; then
    echo_success "Tmux 已安装: $(tmux -V)"
    return 0
  fi

  echo_warning "Tmux 未安装，尝试自动安装..."
  if command -v brew > /dev/null 2>&1; then
    brew install tmux
  elif command -v apt > /dev/null 2>&1; then
    sudo apt install -y tmux
  elif command -v dnf > /dev/null 2>&1; then
    sudo dnf install -y tmux
  elif command -v pacman > /dev/null 2>&1; then
    sudo pacman -S --noconfirm tmux
  else
    echo_warning "请手动安装 tmux"
  fi
}

install_tpm() {
  local tpm_dir="${HOME}/.tmux/plugins/tpm"
  if [[ -d "${tpm_dir}" ]] && [[ -n "$(ls -A "${tpm_dir}" 2>/dev/null)" ]]; then
    echo_success "TPM 已安装"
    return 0
  fi

  echo_step "安装 Tmux Plugin Manager (TPM)..."
  # 镜像源列表（GitHub 官方优先，国内镜像降级）
  local mirrors
  if [[ -n "${NO_MIRROR:-}" ]]; then
    mirrors=("https://github.com/tmux-plugins/tpm.git")
  else
    mirrors=(
      "https://github.com/tmux-plugins/tpm.git"
      "https://ghproxy.net/https://github.com/tmux-plugins/tpm.git"
      "https://gh-proxy.com/https://github.com/tmux-plugins/tpm.git"
    )
  fi

  local cloned=false
  for url in "${mirrors[@]}"; do
    if git clone --depth 1 "${url}" "${tpm_dir}" 2>>"${LOG_FILE}"; then
      cloned=true
      break
    fi
    rm -rf "${tpm_dir}" 2>/dev/null
  done

  if $cloned; then
    echo_success "TPM 安装完成"
    echo "  安装插件: 打开 tmux 后按 前缀键 + I"
  else
    echo_warning "TPM 安装失败（所有镜像源均不可用），可稍后手动安装"
    echo "  git clone https://github.com/tmux-plugins/tpm.git ~/.tmux/plugins/tpm"
  fi
}

main() {
  echo_title "Tmux 配置安装器"
  printf '安装日志将保存到: %s\n' "${LOG_FILE}"

  echo_step "安装 Tmux 配置..."

  # 安装 tmux 二进制（如缺失）
  install_tmux_binary

  # 创建符号链接
  safe_symlink "${TMUX_HOME}/.tmux.conf" "${HOME}/.tmux.conf" || true
  echo_success "Tmux 配置已链接"

  # 安装 TPM
  install_tpm

  echo_success "Tmux 配置安装完成"
  echo "  启动: tmux new -s main"
}

main
