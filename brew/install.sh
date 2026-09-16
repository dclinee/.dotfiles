#!/usr/bin/env bash

# ======================
# Homebrew 安装器
# ======================
#
# 使用 USTC 镜像安装 Homebrew (macOS/Linux)
# 来源：https://mirrors.ustc.edu.cn/help/brew.git.html
#
# 流程：安装/检测 brew → 配置 shellenv → 分层执行 brew bundle
# （通用 Brewfile + 平台 Brewfile，每个文件各调用一次；brew bundle 不支持嵌套 Brewfile）

set -euo pipefail
LOG_FILE="/tmp/dotfiles_install_$(date +%Y%m%d_%H%M%S).log"

# shellcheck source=/dev/null
source "$(dirname "$0")/_common.sh"

BREW_HOME="${BREW_DIR}"

# COMPLETED_STEPS / FAILED_STEPS 追踪（与 bootstrap.sh 顶层机制对齐）
COMPLETED_STEPS=()
FAILED_STEPS=()

# 设置镜像环境变量（默认启用，NO_MIRROR=1 可禁用）
if [[ -z "${NO_MIRROR:-}" ]]; then
  export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.ustc.edu.cn/brew.git"
  export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.ustc.edu.cn/homebrew-core.git"
  export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles"
  export HOMEBREW_API_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles/api"
fi


_detect_brew_prefix() {
  if [[ "$(uname)" == "Linux" ]] && [[ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
    echo "/home/linuxbrew/.linuxbrew"
  elif [[ "$(uname)" == "Darwin" ]] && [[ -x "/opt/homebrew/bin/brew" ]]; then
    echo "/opt/homebrew"
  elif [[ "$(uname)" == "Darwin" ]] && [[ -x "/usr/local/bin/brew" ]]; then
    echo "/usr/local"
  elif command -v brew > /dev/null 2>&1; then
    brew --prefix
  else
    return 1
  fi
}

_install_brew() {
  local mirror_url="https://mirrors.ustc.edu.cn/misc/brew-install.sh"
  if [[ -n "${NO_MIRROR:-}" ]]; then
    mirror_url="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
  fi
  dotfiles_install_script "${mirror_url}" 2>>"${LOG_FILE}"
}

_configure_brew_env() {
  local prefix
  if ! prefix=$(_detect_brew_prefix); then
    echo_warning "brew 未安装，跳过环境配置"
    return 1
  fi
  eval "$("${prefix}/bin/brew" shellenv)" 2>>"${LOG_FILE}" || true
  COMPLETED_STEPS+=("brew-env")
}

# 执行 Brewfile 分层安装（通用包 + 平台包，每文件各调用一次，brew bundle 不支持嵌套）
_bundle_brewfiles() {
  # 1. 通用 Brewfile（约 30 秒 - 2 分钟）
  if [[ -f "${BREW_HOME}/Brewfile" ]]; then
    if is_dry_run; then
      echo_detail "[dry-run] 将执行: brew bundle --file=${BREW_HOME}/Brewfile"
    else
      echo_step "执行 brew bundle（通用包，约 30 秒 - 2 分钟）..."
      brew bundle --file="${BREW_HOME}/Brewfile" 2>>"${LOG_FILE}" || {
        echo_warning "部分通用包安装失败，请查看日志: ${LOG_FILE}"
        FAILED_STEPS+=("brew-bundle-common")
      }
    fi
  fi

  # 2. 平台特定 Brewfile
  local platform_brewfile=""
  case "$(uname -s)" in
    Linux)  platform_brewfile="${BREW_HOME}/Brewfile.linux" ;;
    Darwin) platform_brewfile="${BREW_HOME}/Brewfile.macos" ;;
  esac

  if [[ -n "${platform_brewfile}" ]] && [[ -f "${platform_brewfile}" ]]; then
    if is_dry_run; then
      echo_detail "[dry-run] 将执行: brew bundle --file=${platform_brewfile}"
    else
      echo_step "执行 brew bundle（平台包，约 1 - 5 分钟）..."
      brew bundle --file="${platform_brewfile}" 2>>"${LOG_FILE}" || {
        echo_warning "部分平台包安装失败，请查看日志: ${LOG_FILE}"
        FAILED_STEPS+=("brew-bundle-platform")
      }
    fi
  fi
}

_report() {
  echo_separator
  if [[ ${#FAILED_STEPS[@]} -eq 0 ]]; then
    echo_success "Homebrew 安装完成！"
  else
    echo_warning "以下步骤失败: ${FAILED_STEPS[*]}"
  fi
  if [[ -n "${HOMEBREW_BREW_GIT_REMOTE:-}" ]]; then
    printf '\n已配置以下镜像源：\n'
    printf '  brew.git:       %s\n' "${HOMEBREW_BREW_GIT_REMOTE}"
    printf '  homebrew-core:  %s\n' "${HOMEBREW_CORE_GIT_REMOTE:-}"
    printf '  Bottles:        %s\n' "${HOMEBREW_BOTTLE_DOMAIN:-}"
    printf '  API:            %s\n' "${HOMEBREW_API_DOMAIN:-}"
  fi
  printf '\n请将以下内容添加到你的 shell 配置文件中以持久化：\n'
  printf '  eval "$(brew shellenv)"\n'
}

main() {
  echo_title "Homebrew 安装器"
  printf '安装日志将保存到: %s\n' "${LOG_FILE}"

  if has_brew; then
    echo_success "Homebrew 已安装: $(brew --version | head -1)"
    COMPLETED_STEPS+=("brew-installed")
  else
    echo_step "安装 Homebrew..."
    local install_url
    install_url="${HOMEBREW_BREW_GIT_REMOTE:-https://mirrors.ustc.edu.cn/misc/brew-install.sh}"

    if dotfiles_install_script "${install_url}" 2>>"${LOG_FILE}"; then
      COMPLETED_STEPS+=("brew-install")
    else
      FAILED_STEPS+=("brew-install")
      _report
      return 1
    fi
  fi

  _configure_brew_env || true

  # brew 就绪后执行两层 Brewfile（brew 缺失时无法 bundle，已在上面直接返回）
  _bundle_brewfiles

  _report

  if [[ ${#FAILED_STEPS[@]} -gt 0 ]]; then
    return 1
  fi
}

main
