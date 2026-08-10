#!/usr/bin/env bash

# ======================
# Zsh 配置安装器
# ======================
#
# 注意：brew 安装和 brew bundle 已统一由 bootstrap.sh 处理。
# 如需独立运行此脚本，请先执行: ./bootstrap.sh --brew
# 或直接使用: ./bootstrap.sh --zsh（会自动处理 brew 依赖）

set -euo pipefail
LOG_FILE="/tmp/dotfiles_install_$(date +%Y%m%d_%H%M%S).log"

# 确定配置目录
DOTFILES_DIR="${HOME}/.dotfiles/zsh"
DOTFILES_ROOT="${HOME}/.dotfiles"
ZSH_HOME="${DOTFILES_DIR}"
PLUGINS_DIR="${DOTFILES_DIR}/plugins"

# ======================
# 加载公共输出函数库
# ======================
_OUTPUT_LIB="${DOTFILES_ROOT}/lib/output.sh"
if [[ -f "${_OUTPUT_LIB}" ]]; then
  # shellcheck source=/dev/null
  source "${_OUTPUT_LIB}"
else
  # 回退：当 lib/output.sh 不存在时使用内联定义
  RED="\033[31m"; GREEN="\033[32m"; YELLOW="\033[33m"; BLUE="\033[34m"
  CYAN="\033[36m"; WHITE="\033[37m"; RESET="\033[0m"; BOLD="\033[1m"
  CHECK="✅"; INFO="ℹ️"; WARN="⚠️"; ERROR="❌"; ARROW="➡️"; SKIP="⏭️"
  SEPARATOR="${BLUE}=============================================${RESET}"
  echo_step()      { printf "${BOLD}${BLUE}${INFO} %s${RESET}\n"  "${1}"; }
  echo_success()   { printf "${GREEN}${CHECK} %s${RESET}\n"        "${1}"; }
  echo_warning()   { printf "${YELLOW}${WARN} %s${RESET}\n"        "${1}"; }
  echo_error()     { printf "${RED}${ERROR} %s${RESET}\n"          "${1}"; }
  echo_skip()      { printf "${CYAN}${SKIP} %s${RESET}\n"          "${1}"; }
  echo_detail()    { printf "${BLUE}  %s${RESET}\n"                "${1}"; }
  echo_separator() { printf '%b\n' "${SEPARATOR}"; }
  echo_title() {
    echo_separator
    printf "${BOLD}${CYAN}%s${RESET}\n" "${1}"
    echo_separator
  }
fi

# ======================
# 加载公共符号链接函数库
# ======================
_SYMLINK_LIB="${DOTFILES_ROOT}/lib/symlink.sh"
if [[ -f "${_SYMLINK_LIB}" ]]; then
  # shellcheck source=/dev/null
  source "${_SYMLINK_LIB}"
else
  # 回退：当 lib/symlink.sh 不存在时使用内联定义
  safe_symlink() {
    local src="$1" dst="$2"
    [[ -e "$src" ]] || { echo_warning "源文件不存在: $src"; return 1; }
    if [[ -L "$dst" ]] && [[ "$(readlink "$dst" 2>/dev/null)" == "$src" ]]; then
      echo_skip "链接已存在: $dst"; return 0
    fi
    if [[ -e "$dst" ]] || [[ -L "$dst" ]]; then
      local backup="${dst}.bak.$(date +%Y%m%d_%H%M%S 2>/dev/null || echo bak)"
      mv "$dst" "$backup" 2>/dev/null && echo_warning "已备份: $dst → $backup"
    fi
    mkdir -p "$(dirname "$dst")" 2>/dev/null
    ln -sf "$src" "$dst" 2>/dev/null && echo_detail "已链接: $dst → $src" || { echo_error "链接失败: $dst"; return 1; }
  }
fi

# ======================
# 安全下载并执行脚本
# ======================
# 用法: _download_and_run <url> [args...]
# 替代 curl ... | sh 模式，先下载到临时文件再执行
_download_and_run() {
  local url="$1"
  shift
  local tmp_file
  tmp_file="$(mktemp)"
  # trap 已保证临时文件被清理，函数体内不再手动 rm
  trap 'rm -f "${tmp_file}"' EXIT RETURN

  echo_step "下载脚本: ${url}"
  if ! curl -fsSL "${url}" -o "${tmp_file}" 2>>"${LOG_FILE}"; then
    echo_error "下载失败: ${url}"
    return 1
  fi

  printf "${BOLD}${CYAN}${ARROW} 执行脚本（参数: %s）...${RESET}\n" "$*"
  bash "${tmp_file}" "$@" 2>>"${LOG_FILE}"
}

# ======================
# 插件管理器安装（zinit）
# ======================
install_plugins() {
  echo_step "安装 zinit 插件管理器..."

  if command -v zinit > /dev/null 2>&1; then
    echo_success "zinit 已安装: $(command -v zinit)"
    return 0
  fi

  if command -v brew > /dev/null 2>&1; then
    printf "${BOLD}${CYAN}${ARROW} 通过 brew 安装 zinit...${RESET}\n"
    if brew install zinit > /dev/null 2>&1; then
      echo_success "zinit 安装完成"
    else
      echo_warning "brew 安装 zinit 失败，尝试手动安装"
      _install_zinit_manual
    fi
  else
    _install_zinit_manual
  fi
}

# 手动安装 zinit（当 brew 不可用时，含国内镜像降级）
_install_zinit_manual() {
  printf "${BOLD}${CYAN}${ARROW} 手动安装 zinit...${RESET}\n"
  local zinit_dir="${HOME}/.zinit"

  if [[ -d "${zinit_dir}" ]] && [[ -n "$(ls -A "${zinit_dir}" 2>/dev/null)" ]]; then
    echo_warning "zinit 目录已存在: ${zinit_dir}"
    return 0
  fi

  # 镜像源列表（按优先级，GitHub 官方优先，国内镜像降级）
  local mirrors=(
    "https://github.com/zdharma-continuum/zinit.git"
    "https://ghfast.top/https://github.com/zdharma-continuum/zinit.git"
    "https://mirror.ghproxy.com/https://github.com/zdharma-continuum/zinit.git"
  )

  local cloned=false
  for url in "${mirrors[@]}"; do
    printf "${BOLD}${CYAN}${ARROW} 尝试: %s${RESET}\n" "${url}"
    if git clone --depth 1 "${url}" "${zinit_dir}" 2>>"${LOG_FILE}"; then
      cloned=true
      break
    fi
    echo_warning "此源失败，尝试下一个..."
    rm -rf "${zinit_dir}" 2>/dev/null
  done

  if $cloned; then
    # 添加到 ~/.zshrc.local（避免污染仓库内的 .zshrc 软链文件）
    local local_rc="${HOME}/.zshrc.local"
    if ! grep -q 'zinit' "$local_rc" 2>/dev/null; then
      echo "# zinit 插件管理器（由 install.sh 自动添加）" >> "$local_rc"
      echo "source ${zinit_dir}/zinit.zsh" >> "$local_rc"
    fi
    echo_success "zinit 安装完成（手动）"
    echo_warning "请重启终端或执行: source ~/.zshrc"
  else
    echo_error "zinit 安装失败（所有镜像源均不可用），请查看日志: ${LOG_FILE}"
    return 1
  fi
}

# ======================
# 必备工具安装
# ======================
install_essential_tools() {
  echo_step "检查必备工具..."

  # 安装 starship 主题
  if ! command -v starship > /dev/null; then
    printf "${BOLD}${CYAN}${ARROW} 安装 starship 主题...${RESET}\n"
    if _download_and_run "https://starship.rs/install.sh" -y > /dev/null 2>&1; then
      echo_success "starship 安装完成"
    else
      echo_warning "starship 安装失败，请手动安装: curl -sS https://starship.rs/install.sh | sh"
    fi
  else
    echo_success "starship 已安装"
  fi

  # 安装 eza 和 zoxide
  if ! command -v eza > /dev/null || ! command -v zoxide > /dev/null; then
    printf "${BOLD}${CYAN}${ARROW} 安装 eza 和 zoxide...${RESET}\n"
    if command -v brew > /dev/null; then
      if brew install eza zoxide > /dev/null 2>&1; then
        echo_success "eza 和 zoxide 安装完成"
      else
        echo_warning "eza/zoxide 安装失败，请手动安装"
      fi
    elif command -v apt > /dev/null; then
      sudo apt update > /dev/null 2>&1 || true
      if sudo apt install -y eza zoxide > /dev/null 2>&1; then
        echo_success "eza 和 zoxide 安装完成"
      else
        echo_warning "eza/zoxide 安装失败，请手动安装"
      fi
    elif command -v dnf > /dev/null; then
      if sudo dnf install -y eza zoxide > /dev/null 2>&1; then
        echo_success "eza 和 zoxide 安装完成"
      else
        echo_warning "eza/zoxide 安装失败，请手动安装"
      fi
    elif command -v pacman > /dev/null; then
      if sudo pacman -S --noconfirm eza zoxide > /dev/null 2>&1; then
        echo_success "eza 和 zoxide 安装完成"
      else
        echo_warning "eza/zoxide 安装失败，请手动安装"
      fi
    else
      echo_warning "无法自动安装 eza 或 zoxide，请手动安装"
    fi
  else
    echo_success "eza 和 zoxide 已安装"
  fi
}

# ======================
# zoxide 初始化
# ======================
init_zoxide() {
  if command -v zoxide > /dev/null; then
    echo_step "初始化 zoxide..."
    mkdir -p "${PLUGINS_DIR}/zoxide"
    zoxide init zsh > "${PLUGINS_DIR}/zoxide/init.zsh" 2>>"${LOG_FILE}"
    echo_success "zoxide 初始化完成"
  fi
}

# ======================
# 主安装流程
# ======================
main() {
  echo_title "Zsh 配置安装器"
  echo "安装日志将保存到: ${LOG_FILE}"

  # 创建必要的目录
  echo_step "创建必要目录..."
  mkdir -p "${HOME}/.cache/zsh" "${PLUGINS_DIR}"
  echo_success "目录创建完成"

  # 创建 .zshrc 符号链接
  echo_step "配置 .zshrc 符号链接..."
  if [[ ! -L "${HOME}/.zshrc" ]]; then
    safe_symlink "${DOTFILES_DIR}/.zshrc" "${HOME}/.zshrc" || true
    echo_success "已创建 .zshrc 符号链接"
  else
    echo_warning ".zshrc 符号链接已存在"
  fi

  # 创建 .zshenv 符号链接（用于所有 zsh 会话的环境变量初始化）
  echo_step "配置 .zshenv 符号链接..."
  if [[ ! -L "${HOME}/.zshenv" ]]; then
    safe_symlink "${DOTFILES_DIR}/.zshenv" "${HOME}/.zshenv" || true
    echo_success "已创建 .zshenv 符号链接"
  else
    echo_warning ".zshenv 符号链接已存在"
  fi

  echo_separator

  # 安装必备工具
  install_essential_tools

  echo_separator

  # 安装 Zsh 插件
  install_plugins

  echo_title "安装完成"
  printf "${GREEN}${CHECK} ${BOLD}所有配置安装完成！${RESET}\n"
  printf "${BOLD}${YELLOW}${ARROW} 请执行以下命令生效：${RESET}\n"
  printf "${BOLD}${WHITE}source ~/.zshrc${RESET}\n"
  printf "${BOLD}${YELLOW}${ARROW} 或重启终端${RESET}\n"
  echo_separator
}

# 执行主流程
main
