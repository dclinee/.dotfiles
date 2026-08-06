#!/usr/bin/env bash

# ======================
# Zsh 配置安装器
# ======================

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
_OUTPUT_LIB="${DOTFILES_ROOT}/zsh/lib/output.sh"
if [[ -f "${_OUTPUT_LIB}" ]]; then
  # shellcheck source=/dev/null
  source "${_OUTPUT_LIB}"
else
  # 回退：当 lib/output.sh 不存在时使用内联定义
  RED="\033[31m"; GREEN="\033[32m"; YELLOW="\033[33m"; BLUE="\033[34m"
  CYAN="\033[36m"; WHITE="\033[37m"; RESET="\033[0m"; BOLD="\033[1m"
  CHECK="✅"; INFO="ℹ️"; WARN="⚠️"; ERROR="❌"; ARROW="➡️"
  SEPARATOR="${BLUE}=============================================${RESET}"
  echo_step()    { echo -e "${BOLD}${BLUE}${INFO} ${1}${RESET}"; }
  echo_success() { echo -e "${GREEN}${CHECK} ${1}${RESET}"; }
  echo_warning() { echo -e "${YELLOW}${WARN} ${1}${RESET}"; }
  echo_error()   { echo -e "${RED}${ERROR} ${1}${RESET}"; }
  echo_separator() { echo -e "${SEPARATOR}"; }
  echo_title() {
    echo_separator
    echo -e "${BOLD}${CYAN}${1}${RESET}"
    echo_separator
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
  trap 'rm -f "${tmp_file}"' EXIT RETURN

  echo_step "下载脚本: ${url}"
  if ! curl -fsSL "${url}" -o "${tmp_file}" 2>>"${LOG_FILE}"; then
    echo_error "下载失败: ${url}"
    return 1
  fi

  echo -e "${BOLD}${CYAN}${ARROW} 执行脚本（参数: $*）...${RESET}"
  bash "${tmp_file}" "$@" 2>>"${LOG_FILE}"
  local rc=$?
  rm -f "${tmp_file}"
  return $rc
}

# ======================
# Brew 安装与环境配置
# ======================
install_brew() {
  local brew_bin=""
  local brew_installed=false

  # 检查是否已安装
  if command -v brew > /dev/null 2>&1; then
    brew_bin="$(command -v brew)"
    echo_success "Homebrew 已安装: ${brew_bin}"
    brew_installed=true
  elif [[ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
    brew_bin="/home/linuxbrew/.linuxbrew/bin/brew"
    echo_success "Homebrew 已安装: ${brew_bin}"
    brew_installed=true
  elif [[ -x "/opt/homebrew/bin/brew" ]]; then
    brew_bin="/opt/homebrew/bin/brew"
    echo_success "Homebrew 已安装: ${brew_bin}"
    brew_installed=true
  elif [[ -x "/usr/local/bin/brew" ]]; then
    brew_bin="/usr/local/bin/brew"
    echo_success "Homebrew 已安装: ${brew_bin}"
    brew_installed=true
  fi

  if [[ "$brew_installed" == "true" ]]; then
    eval "$("${brew_bin}" shellenv bash)" 2>/dev/null || true
    return 0
  fi

  # 未安装 → 自动安装
  echo_step "正在安装 Homebrew..."
  local brew_install_url="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
  if [[ "$(uname -s)" == "Linux" ]] || [[ "$(uname -s)" == "Darwin" ]]; then
    # 使用安全下载方式替代 curl | sh
    local tmp_installer
    tmp_installer="$(mktemp)"
    if curl -fsSL "${brew_install_url}" -o "${tmp_installer}" 2>>"${LOG_FILE}"; then
      NONINTERACTIVE=1 /bin/bash "${tmp_installer}" 2>>"${LOG_FILE}" || true
    else
      echo_error "无法下载 Homebrew 安装脚本"
    fi
    rm -f "${tmp_installer}"
  else
    echo_error "不支持的操作系统，无法自动安装 Homebrew"
    return 1
  fi

  # 安装后重新检测
  if command -v brew > /dev/null 2>&1; then
    eval "$(brew shellenv bash)" 2>/dev/null || true
    echo_success "Homebrew 安装成功"
  else
    echo_warning "Homebrew 安装可能未完成，请手动安装后重试"
    return 1
  fi
}

# ======================
# 通过 brew bundle 安装 Brewfile 中的包
# ======================
# brew bundle 不支持嵌套引用其他 Brewfile，
# 因此主 Brewfile 包含通用包，平台特定 Brewfile 仅包含平台差异包，
# 此处按平台依次执行。
brew_bundle_install() {
  if ! command -v brew > /dev/null 2>&1; then
    echo_warning "Homebrew 未就绪，跳过 brew bundle"
    return 0
  fi

  local brew_dir="${DOTFILES_ROOT}/brew"
  local os_name
  os_name="$(uname -s)"

  # 1. 执行通用 Brewfile
  local common_brewfile="${brew_dir}/Brewfile"
  if [[ -f "${common_brewfile}" ]]; then
    echo_step "执行 brew bundle（通用包）..."
    if brew bundle --file="${common_brewfile}" 2>>"${LOG_FILE}"; then
      echo_success "通用包安装完成"
    else
      echo_warning "部分通用包安装失败，请查看日志: ${LOG_FILE}"
    fi
  fi

  # 2. 执行平台特定 Brewfile
  local platform_brewfile=""
  case "${os_name}" in
    Linux)  platform_brewfile="${brew_dir}/Brewfile.linux" ;;
    Darwin) platform_brewfile="${brew_dir}/Brewfile.macos" ;;
  esac

  if [[ -n "${platform_brewfile}" ]] && [[ -f "${platform_brewfile}" ]]; then
    echo_step "执行 brew bundle（${os_name} 平台包）..."
    if brew bundle --file="${platform_brewfile}" 2>>"${LOG_FILE}"; then
      echo_success "${os_name} 平台包安装完成"
    else
      echo_warning "部分平台包安装失败，请查看日志: ${LOG_FILE}"
    fi
  fi
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
    echo -e "${BOLD}${CYAN}${ARROW} 通过 brew 安装 zinit...${RESET}"
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

# 手动安装 zinit（当 brew 不可用时）
_install_zinit_manual() {
  echo -e "${BOLD}${CYAN}${ARROW} 手动安装 zinit...${RESET}"
  local zinit_dir="${HOME}/.zinit"

  if [[ -d "${zinit_dir}" ]]; then
    echo_warning "zinit 目录已存在: ${zinit_dir}"
    return 0
  fi

  if git clone --depth 1 https://github.com/zdharma-continuum/zinit.git "${zinit_dir}" 2>>"${LOG_FILE}"; then
    # 添加到 PATH
    if ! grep -q 'zinit' "${HOME}/.zshrc" 2>/dev/null; then
      echo "# zinit 插件管理器" >> "${HOME}/.zshrc"
      echo "source ${zinit_dir}/zinit.zsh" >> "${HOME}/.zshrc"
    fi
    echo_success "zinit 安装完成（手动）"
    echo_warning "请重启终端或执行: source ~/.zshrc"
  else
    echo_error "zinit 安装失败，请查看日志: ${LOG_FILE}"
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
    echo -e "${BOLD}${CYAN}${ARROW} 安装 starship 主题...${RESET}"
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
    echo -e "${BOLD}${CYAN}${ARROW} 安装 eza 和 zoxide...${RESET}"
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
# Python 配置
# ======================
install_python_config() {
  echo_step "配置 Python 环境..."

  # 检查 Python 3 是否安装
  if ! command -v python3 > /dev/null; then
    echo_error "Python 3 未安装，请先安装 Python 3"
    return 1
  fi

  # 安装 pip
  if ! command -v pip3 > /dev/null; then
    echo -e "${BOLD}${CYAN}${ARROW} 安装 pip...${RESET}"
    if python3 -m ensurepip --upgrade > /dev/null 2>&1; then
      echo_success "pip 安装完成"
    else
      echo_warning "pip 安装失败，请手动安装: python3 -m ensurepip --upgrade"
    fi
  fi

  # 安装 Python 依赖
  if [[ -f "${HOME}/.dotfiles/python/requirements.txt" ]]; then
    echo -e "${BOLD}${CYAN}${ARROW} 安装 Python 依赖...${RESET}"
    if pip3 install --upgrade -r "${HOME}/.dotfiles/python/requirements.txt" > /dev/null 2>&1; then
      echo_success "Python 依赖安装完成"
    else
      echo_warning "Python 依赖安装失败，请手动安装: pip3 install -r ${HOME}/.dotfiles/python/requirements.txt"
    fi
  fi

  # 确保 Python 相关目录存在
  mkdir -p "${HOME}/.virtualenvs" "${HOME}/.cache/pip" > /dev/null 2>&1

  # 配置 pip 符号链接
  if [[ ! -L "${HOME}/.pip/pip.conf" ]] && [[ ! -f "${HOME}/.pip/pip.conf" ]]; then
    mkdir -p "${HOME}/.pip" > /dev/null 2>&1
    ln -sf "${HOME}/.dotfiles/python/pip.conf" "${HOME}/.pip/pip.conf" > /dev/null 2>&1
    echo_success "已创建 pip.conf 符号链接"
  fi

  echo_success "Python 环境配置完成"
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
# Nerd Font 检测与安装
# ======================
# 检测 Nerd Font 是否已安装
_has_nerd_font_install() {
  # 方法1: fc-list
  if command -v fc-list > /dev/null 2>&1; then
    fc-list : family 2>/dev/null | grep -qi "Nerd" && return 0
  fi

  # 方法2: 检查常见字体目录
  local dir
  for dir in \
    "${HOME}/.local/share/fonts" \
    "${HOME}/.fonts" \
    "/usr/local/share/fonts" \
    "/usr/share/fonts" \
    "/usr/share/fonts/truetype" \
    "/usr/share/fonts/opentype"; do
    [[ -d "${dir}" ]] && find "${dir}" -iname "*Nerd*" -print -quit 2>/dev/null | grep -q . && return 0
  done

  # 方法3: brew 字体
  if command -v brew > /dev/null 2>&1; then
    local prefix="${HOMEBREW_PREFIX:-/home/linuxbrew/.linuxbrew}"
    [[ -d "${prefix}/share/fonts" ]] && find "${prefix}/share/fonts" -iname "*Nerd*" -print -quit 2>/dev/null | grep -q . && return 0
  fi

  return 1
}

# 安装 Nerd Font (Fira Code Nerd Font)
install_nerd_font() {
  echo_step "检查 Nerd Font..."

  if _has_nerd_font_install; then
    echo_success "Nerd Font 已安装"
    return 0
  fi

  echo -e "${BOLD}${CYAN}${ARROW} 安装 Fira Code Nerd Font...${RESET}"

  local font_dir="${HOME}/.local/share/fonts"
  local font_name="FiraCode"
  local nerd_version="3.3.0"
  local url="https://github.com/ryanoasis/nerd-fonts/releases/download/v${nerd_version}/${font_name}.zip"
  local tmp_zip

  tmp_zip="$(mktemp /tmp/nerd-font-XXXXXX.zip)"

  # 下载
  if ! curl -fsSL "${url}" -o "${tmp_zip}" 2>>"${LOG_FILE}"; then
    echo_warning "Nerd Font 下载失败，Starship 将使用降级模式（无图标）"
    echo "  手动安装: https://www.nerdfonts.com/font-downloads"
    rm -f "${tmp_zip}"
    return 1
  fi

  # 解压到字体目录
  mkdir -p "${font_dir}"
  if command -v unzip > /dev/null 2>&1; then
    if unzip -o -q "${tmp_zip}" -d "${font_dir}" 2>>"${LOG_FILE}"; then
      echo_success "Nerd Font 已安装到 ${font_dir}"
    else
      echo_warning "Nerd Font 解压失败"
      rm -f "${tmp_zip}"
      return 1
    fi
  else
    echo_warning "未安装 unzip，无法解压字体包"
    echo "  安装 unzip: sudo apt install unzip"
    rm -f "${tmp_zip}"
    return 1
  fi

  # 刷新字体缓存
  if command -v fc-cache > /dev/null 2>&1; then
    fc-cache -fv "${font_dir}" > /dev/null 2>&1
    echo_success "字体缓存已刷新"
  fi

  # 清理下载的临时文件
  rm -f "${tmp_zip}"

  # 清除 Nerd Font 检测缓存（让下次启动重新检测）
  rm -f "${HOME}/.cache/zsh/nerd_font_cache" 2>/dev/null

  echo_warning "请重启终端或在终端设置中选择 Nerd Font 字体"
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
    ln -sf "${DOTFILES_DIR}/.zshrc" "${HOME}/.zshrc"
    echo_success "已创建 .zshrc 符号链接"
  else
    echo_warning ".zshrc 符号链接已存在"
  fi

  # 创建 .zshenv 符号链接（用于所有 zsh 会话的环境变量初始化）
  echo_step "配置 .zshenv 符号链接..."
  if [[ ! -L "${HOME}/.zshenv" ]]; then
    ln -sf "${DOTFILES_DIR}/.zshenv" "${HOME}/.zshenv"
    echo_success "已创建 .zshenv 符号链接"
  else
    echo_warning ".zshenv 符号链接已存在"
  fi

  echo_separator

  # 安装 Homebrew
  install_brew

  echo_separator

  # 通过 brew bundle 安装 Brewfile 中的包
  brew_bundle_install

  echo_separator

  # 安装必备工具
  install_essential_tools

  echo_separator

  # 安装 Zsh 插件
  install_plugins

  echo_separator

  # 配置 Python 环境
  install_python_config

  echo_separator

  # 初始化 zoxide
  init_zoxide

  echo_separator

  # 安装 Nerd Font（用于 Starship 图标显示）
  install_nerd_font

  echo_title "安装完成"
  echo -e "${GREEN}${CHECK} ${BOLD}所有配置安装完成！${RESET}"
  echo -e "${BOLD}${YELLOW}${ARROW} 请执行以下命令生效：${RESET}"
  echo -e "${BOLD}${WHITE}source ~/.zshrc${RESET}"
  echo -e "${BOLD}${YELLOW}${ARROW} 或重启终端${RESET}"
  echo_separator
}

# 执行主流程
main
