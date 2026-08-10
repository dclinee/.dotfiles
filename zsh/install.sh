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
    printf "${BOLD}${CYAN}${ARROW} 安装 pip...${RESET}\n"
    if python3 -m ensurepip --upgrade > /dev/null 2>&1; then
      echo_success "pip 安装完成"
    else
      echo_warning "pip 安装失败，请手动安装: python3 -m ensurepip --upgrade"
    fi
  fi

  # 安装 Python 依赖（与 bootstrap.sh install_python 同步：PEP 668 兼容，pipx 优先）
  if [[ -f "${HOME}/.dotfiles/python/requirements.txt" ]]; then
    printf "${BOLD}${CYAN}${ARROW} 安装 Python 基础依赖...${RESET}\n"
    local req_file="${HOME}/.dotfiles/python/requirements.txt"

    # 工具：如未安装 pipx 则尝试用 brew/apt 一键安装（跨平台），失败返回 false
    _ensure_pipx() {
      if command -v pipx > /dev/null 2>&1; then
        return 0
      fi
      printf "${BOLD}${CYAN}${ARROW} 自动安装 pipx...${RESET}\n"
      if command -v brew > /dev/null 2>&1; then
        brew install pipx > /dev/null 2>&1 || return 1
      elif command -v apt > /dev/null 2>&1; then
        sudo apt update -qq > /dev/null 2>&1 || true
        sudo apt install -y -qq pipx > /dev/null 2>&1 || return 1
      elif command -v dnf > /dev/null 2>&1; then
        sudo dnf install -y pipx > /dev/null 2>&1 || return 1
      elif command -v pacman > /dev/null 2>&1; then
        sudo pacman -S --noconfirm python-pipx > /dev/null 2>&1 || return 1
      else
        # 无包管理器：用 pip 本身 bootstrap（仅在非 PEP 668 环境可行）
        pip3 install --user pipx > /dev/null 2>&1 || return 1
      fi
      # pipx ensurepath 确保命令入 PATH（输出静默，下次 shell 生效）
      pipx ensurepath > /dev/null 2>&1 || true
      # 保证当前脚本内也能找到 pipx
      if [[ -d "${HOME}/.local/bin" ]]; then
        export PATH="${HOME}/.local/bin:${PATH}"
      fi
      command -v pipx > /dev/null 2>&1
    }

    # 工具：在共享虚拟环境中安装（终极兜底：~/Library/Caches 或 ~/.cache）
    _install_in_venv() {
      local venv_dir
      if [[ "$(uname -s)" == "Darwin" ]]; then
        venv_dir="${HOME}/Library/Caches/dotfiles-py-venv"
      else
        venv_dir="${HOME}/.cache/dotfiles-py-venv"
      fi
      printf "${BOLD}${CYAN}${ARROW} 创建独立虚拟环境安装: %s${RESET}\n" "${venv_dir}"
      python3 -m venv "${venv_dir}" 2>>"${LOG_FILE}" || return 1
      "${venv_dir}/bin/pip" install --upgrade pip > /dev/null 2>&1 || true
      if "${venv_dir}/bin/pip" install -r "${req_file}" 2>>"${LOG_FILE}"; then
        # 把该 venv bin 入到 PATH（通过写入到 ~/.local/share/dotfiles-py-path 让 zsh 启动时读取）
        local marker="${HOME}/.local/share/dotfiles-py-path"
        mkdir -p "$(dirname "${marker}")"
        printf '%s\n' "${venv_dir}/bin" > "${marker}"
        return 0
      fi
      return 1
    }

    local installed=false
    local externally_managed=false
    if pip3 install --dry-run "pip" 2>&1 | grep -qi "externally-managed"; then
      externally_managed=true
    fi

    if $externally_managed; then
      echo_warning "检测到 PEP 668 外部管理环境，不使用 --user"
      if _ensure_pipx; then
        printf "${BOLD}${CYAN}${ARROW} 使用 pipx 安装必装依赖...${RESET}\n"
        if pipx install --include-deps -r "${req_file}" 2>>"${LOG_FILE}"; then
          echo_success "Python 基础依赖通过 pipx 安装完成"
          installed=true
        fi
      fi
    else
      # 先尝试 --user
      if pip3 install --user --upgrade -r "${req_file}" 2>>"${LOG_FILE}"; then
        echo_success "Python 基础依赖安装完成"
        installed=true
      else
        echo_warning "pip3 --user 安装失败，切换到 pipx"
        if _ensure_pipx; then
          if pipx install --include-deps -r "${req_file}" 2>>"${LOG_FILE}"; then
            echo_success "Python 基础依赖通过 pipx 安装完成"
            installed=true
          fi
        fi
      fi
    fi

    # pipx 也失败时，落到 venv 兜底（不再报错，给用户明确路径）
    if ! $installed; then
      if _install_in_venv; then
        echo_success "Python 基础依赖已安装到独立虚拟环境"
        echo "  该环境已写入: ~/.local/share/dotfiles-py-path，启动新 zsh 会自动入 PATH"
        echo "  或当前会话临时生效: export PATH=\"\$(cat ~/.local/share/dotfiles-py-path):\$PATH\""
        installed=true
      fi
    fi

    if ! $installed; then
      echo_warning "自动安装失败，请手动选择以下方式之一:"
      echo "    1. 安装 pipx:  brew install pipx  |  sudo apt install pipx"
      echo "       然后: pipx install --include-deps -r ${req_file}"
      echo "    2. 虚拟环境: python3 -m venv ~/.venv-dotfiles && source ~/.venv-dotfiles/bin/activate && pip install -r ${req_file}"
    fi

    echo "  按需安装其他依赖（不自动安装）:"
    echo "    开发工具: pip3 install -r ~/.dotfiles/python/requirements-dev.txt"
    echo "    数据处理: pip3 install -r ~/.dotfiles/python/requirements-data.txt"
    echo "    Web 开发: pip3 install -r ~/.dotfiles/python/requirements-web.txt"
  fi

  # 确保 Python 相关目录存在
  mkdir -p "${HOME}/.virtualenvs" "${HOME}/.cache/pip" > /dev/null 2>&1

  # 配置 pip 符号链接
  if [[ ! -L "${HOME}/.pip/pip.conf" ]] && [[ ! -f "${HOME}/.pip/pip.conf" ]]; then
    mkdir -p "${HOME}/.pip" > /dev/null 2>&1
    safe_symlink "${HOME}/.dotfiles/python/pip.conf" "${HOME}/.pip/pip.conf" || true
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
