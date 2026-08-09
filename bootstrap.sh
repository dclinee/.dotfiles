#!/usr/bin/env bash

# ======================
# Dotfiles 一键安装脚本
# ======================
#
# 在新机器上只需执行:
#   curl -fsSL https://raw.githubusercontent.com/dclinee/.dotfiles/main/bootstrap.sh | bash
#
# 或手动:
#   git clone https://github.com/dclinee/.dotfiles.git ~/.dotfiles
#   cd ~/.dotfiles && ./bootstrap.sh
#
# 支持参数:
#   ./bootstrap.sh --all      安装全部（默认）
#   ./bootstrap.sh --zsh      仅安装 Zsh
#   ./bootstrap.sh --vim      仅安装 Vim
#   ./bootstrap.sh --emacs    仅安装 Emacs
#   ./bootstrap.sh --wezterm  仅安装 WezTerm
#   ./bootstrap.sh --brew     仅安装 Brew 包
#   ./bootstrap.sh --python   仅配置 Python
#   ./bootstrap.sh --rust     仅配置 Rust 环境
#   ./bootstrap.sh --tmux     仅安装 Tmux
#   ./bootstrap.sh --git      仅安装 Git 配置
#   ./bootstrap.sh --editorconfig  仅安装 EditorConfig
#   ./bootstrap.sh --skip-fonts    跳过字体安装（下载慢时使用）

set -euo pipefail

# ======================
# 变量定义
# ======================
DOTFILES_DIR="${HOME}/.dotfiles"
LOG_FILE="/tmp/dotfiles_bootstrap_$(date +%Y%m%d_%H%M%S).log"

# 安装选项（默认全部安装）
INSTALL_ALL=true
INSTALL_ZSH=false
INSTALL_VIM=false
INSTALL_EMACS=false
INSTALL_WEZTERM=false
INSTALL_BREW=false
INSTALL_PYTHON=false
INSTALL_RUST=false
INSTALL_TMUX=false
INSTALL_GIT=false
INSTALL_EDITORCONFIG=false
SKIP_FONTS=false

# ======================
# 颜色与输出
# ======================
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
CYAN="\033[36m"
RESET="\033[0m"
BOLD="\033[1m"

echo_step()      { printf "${BOLD}${BLUE}ℹ️  %s${RESET}\n"  "${1}"; }
echo_success()   { printf "${GREEN}✅ %s${RESET}\n"         "${1}"; }
echo_warning()   { printf "${YELLOW}⚠️  %s${RESET}\n"       "${1}"; }
echo_error()     { printf "${RED}❌ %s${RESET}\n"           "${1}"; }
echo_separator() { printf "${BLUE}=============================================${RESET}\n"; }
echo_title() {
  echo_separator
  printf "${BOLD}${CYAN}%s${RESET}\n" "${1}"
  echo_separator
}

# ======================
# 参数解析
# ======================
parse_args() {
  if [[ $# -eq 0 ]]; then
    return
  fi

  INSTALL_ALL=false
  for arg in "$@"; do
    case "$arg" in
      --all)      INSTALL_ALL=true ;;
      --zsh)      INSTALL_ZSH=true ;;
      --vim)      INSTALL_VIM=true ;;
      --emacs)    INSTALL_EMACS=true ;;
      --wezterm)  INSTALL_WEZTERM=true ;;
      --brew)     INSTALL_BREW=true ;;
      --python)   INSTALL_PYTHON=true ;;
      --rust)     INSTALL_RUST=true ;;
      --tmux)     INSTALL_TMUX=true ;;
      --git)      INSTALL_GIT=true ;;
      --editorconfig) INSTALL_EDITORCONFIG=true ;;
      --skip-fonts)   SKIP_FONTS=true ;;
      -h|--help)
        head -30 "$0" | tail -25
        exit 0
        ;;
      *)
        echo_error "未知参数: $arg"
        echo "使用: $0 [--all|--zsh|--vim|--emacs|--wezterm|--brew|--python|--rust|--tmux|--git|--editorconfig|--skip-fonts]"
        exit 1
        ;;
    esac
  done
}

# ======================
# 前置检查
# ======================
check_prerequisites() {
  echo_step "检查前置依赖..."

  local missing=()

  if ! command -v git > /dev/null 2>&1; then
    missing+=("git")
  fi

  if ! command -v curl > /dev/null 2>&1; then
    missing+=("curl")
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo_error "缺少前置依赖: ${missing[*]}"
    echo ""
    echo "安装方式:"
    echo "  Ubuntu/Debian: sudo apt update && sudo apt install -y ${missing[*]}"
    echo "  CentOS/RHEL:   sudo dnf install -y ${missing[*]}"
    echo "  macOS:         xcode-select --install"
    exit 1
  fi

  echo_success "前置依赖检查通过"
}

# ======================
# 克隆仓库
# ======================
clone_repo() {
  if [[ -d "${DOTFILES_DIR}/.git" ]]; then
    echo_success "Dotfiles 仓库已存在"
    return 0
  fi

  echo_step "克隆 Dotfiles 仓库..."
  if git clone https://github.com/dclinee/.dotfiles.git "${DOTFILES_DIR}" 2>>"${LOG_FILE}"; then
    echo_success "仓库克隆完成"
  else
    echo_error "仓库克隆失败，请检查网络或手动克隆"
    echo "  git clone https://github.com/dclinee/.dotfiles.git ~/.dotfiles"
    exit 1
  fi
}

# ======================
# 安装 Zsh 配置
# ======================
install_zsh() {
  echo_step "安装 Zsh 配置..."

  # 检查 zsh 是否安装
  if ! command -v zsh > /dev/null 2>&1; then
    echo_warning "Zsh 未安装，正在安装..."
    if command -v apt > /dev/null 2>&1; then
      sudo apt update -qq && sudo apt install -y -qq zsh
    elif command -v dnf > /dev/null 2>&1; then
      sudo dnf install -y zsh
    elif command -v pacman > /dev/null 2>&1; then
      sudo pacman -S --noconfirm zsh
    elif command -v brew > /dev/null 2>&1; then
      brew install zsh
    else
      echo_error "无法自动安装 Zsh，请手动安装后重试"
      return 1
    fi
  fi

  # 运行 zsh 安装脚本
  bash "${DOTFILES_DIR}/zsh/install.sh" 2>>"${LOG_FILE}" || {
    echo_warning "Zsh 安装脚本出现错误，请查看日志: ${LOG_FILE}"
  }

  # 询问是否设为默认 shell（跨平台：Linux 用 getent，macOS 用 dscl）
  _current_login_shell() {
    if command -v getent > /dev/null 2>&1; then
      getent passwd "$USER" 2>/dev/null | cut -d: -f7
    else
      # macOS/BSD: 通过 dscl 读取用户记录
      dscl . -read "/Users/${USER}" UserShell 2>/dev/null | awk '{print $2}'
    fi
  }

  if [[ "$(_current_login_shell)" != "$(command -v zsh)" ]]; then
    echo_warning "当前默认 shell 不是 zsh"
    echo "  设置默认 shell: chsh -s $(command -v zsh)"
  fi
}

# ======================
# 安装 Vim 配置
# ======================
install_vim() {
  echo_step "安装 Vim 配置..."

  local vimrc_src="${DOTFILES_DIR}/vim/.vimrc"
  local vimrc_dst="${HOME}/.vimrc"

  # 创建符号链接
  if [[ -L "${vimrc_dst}" ]]; then
    echo_warning ".vimrc 链接已存在"
  elif [[ -f "${vimrc_dst}" ]]; then
    echo_warning "发现现有 .vimrc，备份为 .vimrc.bak"
    mv "${vimrc_dst}" "${vimrc_dst}.bak"
    ln -sf "${vimrc_src}" "${vimrc_dst}"
    echo_success ".vimrc 链接已创建"
  else
    ln -sf "${vimrc_src}" "${vimrc_dst}"
    echo_success ".vimrc 链接已创建"
  fi

  # 确保缓存目录存在
  mkdir -p "${HOME}/.cache/vim/undo" "${HOME}/.cache/vim/backup" "${HOME}/.cache/vim/swap"

  echo_success "Vim 配置安装完成"
}

# ======================
# 安装 Emacs 配置
# ======================
install_emacs() {
  echo_step "安装 Emacs 配置..."
  bash "${DOTFILES_DIR}/emacs/install.sh" 2>>"${LOG_FILE}" || {
    echo_warning "Emacs 安装出现错误，请查看日志: ${LOG_FILE}"
  }
}

# ======================
# 安装 WezTerm 配置
# ======================
install_wezterm() {
  echo_step "安装 WezTerm 配置..."
  bash "${DOTFILES_DIR}/wezterm/install.sh" 2>>"${LOG_FILE}" || {
    echo_warning "WezTerm 安装出现错误，请查看日志: ${LOG_FILE}"
  }
}

# ======================
# 安装 Homebrew 包
# ======================
install_brew() {
  echo_step "安装 Homebrew 包..."

  if ! command -v brew > /dev/null 2>&1; then
    echo_warning "Homebrew 未安装，尝试安装..."
    bash "${DOTFILES_DIR}/brew/install_brew.sh" 2>>"${LOG_FILE}" || {
      echo_warning "Homebrew 安装失败，跳过 brew bundle"
      return 0
    }
  fi

  # 1. 执行通用 Brewfile（约 30 秒 - 2 分钟）
  if [[ -f "${DOTFILES_DIR}/brew/Brewfile" ]]; then
    echo_step "执行 brew bundle（通用包，约 30 秒 - 2 分钟）..."
    brew bundle --file="${DOTFILES_DIR}/brew/Brewfile" 2>>"${LOG_FILE}" || {
      echo_warning "部分通用包安装失败，请查看日志: ${LOG_FILE}"
    }
  fi

  # 2. 执行平台特定 Brewfile
  local platform_brewfile=""
  local platform_fontfile=""
  case "$(uname -s)" in
    Linux)  platform_brewfile="${DOTFILES_DIR}/brew/Brewfile.linux" ;;
    Darwin)
      platform_brewfile="${DOTFILES_DIR}/brew/Brewfile.macos"
      platform_fontfile="${DOTFILES_DIR}/brew/Brewfile.fonts"
      ;;
  esac

  # 2a. 平台应用包（GUI 应用 + App Store + 服务，约 1 - 5 分钟）
  if [[ -n "${platform_brewfile}" ]] && [[ -f "${platform_brewfile}" ]]; then
    echo_step "执行 brew bundle（平台包，约 1 - 5 分钟）..."
    brew bundle --file="${platform_brewfile}" 2>>"${LOG_FILE}" || {
      echo_warning "部分平台包安装失败，请查看日志: ${LOG_FILE}"
    }
  fi

  # 2b. 字体安装（慢步骤，约 2 - 15 分钟，可能需要更长）
  if [[ "${SKIP_FONTS}" != "true" ]] && [[ -n "${platform_fontfile}" ]] && [[ -f "${platform_fontfile}" ]]; then
    echo_step "安装 Nerd Font 字体（可能需要 2 - 15 分钟，首次下载较大）..."
    echo "  如遇下载缓慢，可按 Ctrl+C 终止后用 --skip-fonts 跳过"
    echo "  或单独安装: brew install --cask font-fira-code-nerd-font"

    # 字体下载超时保护：若 120 秒内无进度变化则跳过
    local font_timeout=120
    local font_start_time
    font_start_time=$(date +%s)

    if timeout "${font_timeout}" brew bundle --file="${platform_fontfile}" 2>>"${LOG_FILE}"; then
      echo_success "字体安装完成"
    else
      local font_elapsed
      font_elapsed=$(($(date +%s) - font_start_time))
      if [[ $font_elapsed -ge $font_timeout ]]; then
        echo_warning "字体下载超时（${font_elapsed} 秒），已跳过"
        echo "  网络较慢时可用其他方式安装:"
        echo "    1. 手动下载: https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.0/FiraCode.tar.xz"
        echo "    2. 解压缩后放到 ~/Library/Fonts/"
        echo "    3. 或: brew install --cask font-fira-code-nerd-font（网络良好时重试）"
      else
        echo_warning "字体安装失败（耗时 ${font_elapsed} 秒），请查看日志: ${LOG_FILE}"
      fi
    fi
  elif [[ "${SKIP_FONTS}" == "true" ]]; then
    echo_step "已跳过字体安装（--skip-fonts）"
    echo "  后续安装: brew install --cask font-fira-code-nerd-font"
  fi

  echo_success "Homebrew 包安装完成"
}

# ======================
# 配置 Python 环境
# ======================
install_python() {
  echo_step "配置 Python 环境..."

  if ! command -v python3 > /dev/null 2>&1; then
    echo_warning "Python3 未安装，跳过配置"
    return 0
  fi

  # pip 配置链接
  mkdir -p "${HOME}/.pip"
  if [[ ! -L "${HOME}/.pip/pip.conf" ]]; then
    ln -sf "${DOTFILES_DIR}/python/pip.conf" "${HOME}/.pip/pip.conf"
  fi

  # 安装必装依赖（PEP 668 兼容：优先 pipx，否则 --user；失败不吞）
  if [[ -f "${DOTFILES_DIR}/python/requirements.txt" ]]; then
    echo_step "安装 Python 必装依赖..."
    # 检测是否为外部管理环境（Debian/Ubuntu 23+）
    if pip3 install --dry-run "pip" 2>&1 | grep -qi "externally-managed"; then
      echo_warning "检测到 PEP 668 外部管理环境"
      if command -v pipx > /dev/null 2>&1; then
        echo_step "使用 pipx 安装必装依赖..."
        if ! pipx install --include-deps -r "${DOTFILES_DIR}/python/requirements.txt" 2>>"${LOG_FILE}"; then
          echo_error "Python 必装依赖安装失败，请查看日志: ${LOG_FILE}"
          echo "  备选方案: python3 -m venv ~/.venv && source ~/.venv/bin/activate && pip install -r python/requirements.txt"
          return 1
        fi
      else
        echo_warning "未找到 pipx，跳过自动安装"
        echo "  建议安装 pipx:  brew install pipx  或  apt install pipx"
        echo "  或在虚拟环境中安装:  python3 -m venv ~/.venv && pip install -r python/requirements.txt"
      fi
    else
      # 非外部管理环境，直接 --user 安装
      if ! pip3 install --user -r "${DOTFILES_DIR}/python/requirements.txt" 2>>"${LOG_FILE}"; then
        echo_error "Python 必装依赖安装失败，请查看日志: ${LOG_FILE}"
        return 1
      fi
    fi
  fi

  # 提示可选依赖（不自动安装，避免失败噪音）
  local optional_files=("requirements-dev.txt" "requirements-data.txt" "requirements-web.txt")
  local opt_file
  for opt_file in "${optional_files[@]}"; do
    if [[ -f "${DOTFILES_DIR}/python/${opt_file}" ]]; then
      echo_step "可选依赖（不自动安装）: ${opt_file}"
      echo "  按需安装: pip3 install --user -r python/${opt_file}"
      break  # 只提示一次
    fi
  done

  echo_success "Python 环境配置完成"
}

# ======================
# 配置 Rust 环境
# ======================
install_rust() {
  echo_step "配置 Rust 环境..."
  bash "${DOTFILES_DIR}/rust/install.sh" 2>>"${LOG_FILE}" || {
    echo_warning "Rust 安装出现错误，请查看日志: ${LOG_FILE}"
  }
}

# ======================
# 安装 Tmux 配置
# ======================
install_tmux() {
  echo_step "安装 Tmux 配置..."

  if ! command -v tmux > /dev/null 2>&1; then
    echo_warning "Tmux 未安装"
    if command -v brew > /dev/null 2>&1; then
      brew install tmux
    elif command -v apt > /dev/null 2>&1; then
      sudo apt install -y tmux
    elif command -v dnf > /dev/null 2>&1; then
      sudo dnf install -y tmux
    else
      echo_warning "请手动安装 tmux"
    fi
  fi

  # 创建符号链接
  ln -sf "${DOTFILES_DIR}/tmux/.tmux.conf" "${HOME}/.tmux.conf"
  echo_success "Tmux 配置已链接"

  # 安装 TPM (Tmux Plugin Manager，含国内镜像降级)
  local tpm_dir="${HOME}/.tmux/plugins/tpm"
  if [[ ! -d "${tpm_dir}" ]] || [[ -z "$(ls -A "${tpm_dir}" 2>/dev/null)" ]]; then
    echo_step "安装 Tmux Plugin Manager (TPM)..."
    # 镜像源列表（GitHub 官方优先，国内镜像降级）
    local tpm_mirrors=(
      "https://github.com/tmux-plugins/tpm.git"
      "https://ghfast.top/https://github.com/tmux-plugins/tpm.git"
      "https://mirror.ghproxy.com/https://github.com/tmux-plugins/tpm.git"
    )
    local tpm_cloned=false
    for tpm_url in "${tpm_mirrors[@]}"; do
      if git clone --depth 1 "${tpm_url}" "${tpm_dir}" 2>>"${LOG_FILE}"; then
        tpm_cloned=true
        break
      fi
      rm -rf "${tpm_dir}" 2>/dev/null
    done
    if $tpm_cloned; then
      echo_success "TPM 安装完成"
      echo "  安装插件: 打开 tmux 后按 前缀键 + I"
    else
      echo_warning "TPM 安装失败（所有镜像源均不可用），可稍后手动安装"
      echo "  git clone https://github.com/tmux-plugins/tpm.git ~/.tmux/plugins/tpm"
    fi
  else
    echo_success "TPM 已安装"
  fi
}

# ======================
# 安装 Git 配置
# ======================
install_git() {
  echo_step "安装 Git 配置..."

  # .gitconfig
  ln -sf "${DOTFILES_DIR}/git/.gitconfig" "${HOME}/.gitconfig"

  # .gitignore_global
  ln -sf "${DOTFILES_DIR}/git/.gitignore_global" "${HOME}/.gitignore_global"

  echo_success "Git 配置已链接"

  # 创建 .gitconfig.local 模板（如不存在）
  local local_config="${HOME}/.gitconfig.local"
  if [[ ! -f "${local_config}" ]]; then
    cat > "${local_config}" << 'GITLOCAL_EOF'
# Git 个人配置（不提交到仓库）
# 请修改以下信息为你自己的（替换 YOUR_NAME / YOUR_EMAIL）

[user]
    name = YOUR_NAME
    email = YOUR_EMAIL

# 可在此添加其他个人配置，如：
# [commit]
#     gpgsign = true
# [user]
#     signingkey = YOUR_GPG_KEY
GITLOCAL_EOF
    echo_warning "已创建 ~/.gitconfig.local 模板，请修改其中的用户信息"
    echo "  vim ~/.gitconfig.local"
  else
    echo_success ".gitconfig.local 已存在"
  fi

  # 验证用户信息是否已配置
  if ! git config user.name >/dev/null 2>&1 || [[ "$(git config user.name)" == "Your Name" ]]; then
    echo_warning "Git 用户信息未配置，请编辑 ~/.gitconfig.local"
  fi
}

# ======================
# 创建 .editorconfig 链接
# ======================
install_editorconfig() {
  echo_step "配置 .editorconfig..."
  ln -sf "${DOTFILES_DIR}/.editorconfig" "${HOME}/.editorconfig"
  echo_success ".editorconfig 已链接"
}

# ======================
# 最终验证
# ======================
final_check() {
  echo_title "安装验证"
  local all_good=true

  # 检查 Zsh
  if [[ -L "${HOME}/.zshrc" ]]; then
    echo_success "Zsh: .zshrc 已链接"
  else
    echo_error "Zsh: .zshrc 未链接"
    all_good=false
  fi

  # 检查 Vim
  if [[ -L "${HOME}/.vimrc" ]]; then
    echo_success "Vim: .vimrc 已链接"
  else
    echo_error "Vim: .vimrc 未链接"
    all_good=false
  fi

  # 检查 Emacs
  if [[ -L "${HOME}/.config/emacs/init.el" ]] || [[ -L "${HOME}/.emacs.d/init.el" ]]; then
    echo_success "Emacs: init.el 已链接"
  else
    echo_warning "Emacs: init.el 未链接（可能未选择安装）"
  fi

  # 检查 Git
  if [[ -L "${HOME}/.gitconfig" ]]; then
    echo_success "Git: .gitconfig 已链接"
  else
    echo_error "Git: .gitconfig 未链接"
    all_good=false
  fi

  # 检查 Tmux
  if [[ -L "${HOME}/.tmux.conf" ]]; then
    echo_success "Tmux: .tmux.conf 已链接"
  else
    echo_error "Tmux: .tmux.conf 未链接"
    all_good=false
  fi

  # 检查 WezTerm
  if [[ -L "${HOME}/.wezterm.lua" ]]; then
    echo_success "WezTerm: .wezterm.lua 已链接"
  else
    echo_warning "WezTerm: .wezterm.lua 未链接（可能未安装 WezTerm）"
  fi

  # 检查 EditorConfig
  if [[ -L "${HOME}/.editorconfig" ]]; then
    echo_success "EditorConfig: 已链接"
  else
    echo_error "EditorConfig: 未链接"
    all_good=false
  fi

  echo ""
  if $all_good; then
    echo_title "安装完成！"
    printf "${GREEN}✅ 所有配置安装成功！${RESET}\n"
    echo ""
    printf "${BOLD}下一步:${RESET}\n"
    echo "  1. 设置默认 shell:  chsh -s \$(which zsh)"
    echo "  2. 配置 Git 用户:   编辑 ~/.gitconfig.local"
    echo "  3. 重启终端或执行:  source ~/.zshrc"
    echo "  4. 安装 tmux 插件:  tmux → 前缀键 + I"
    echo ""
    echo "安装日志: ${LOG_FILE}"
  else
    echo_warning "部分配置未完成，请查看上方错误信息"
    echo "安装日志: ${LOG_FILE}"
  fi
}

# ======================
# 主流程
# ======================
main() {
  parse_args "$@"

  echo_title "Dotfiles 一键安装"
  echo "安装日志: ${LOG_FILE}"
  echo ""

  # 安装步骤追踪（用于错误回滚和报告）
  declare -a COMPLETED_STEPS=()
  declare -a FAILED_STEPS=()

  # 前置检查
  check_prerequisites

  # 确保仓库存在
  clone_repo

  cd "${DOTFILES_DIR}"
  echo_success "当前目录: $(pwd)"
  echo ""

  # 安装组件（每个组件独立执行，失败不中断后续步骤）
  if $INSTALL_ALL || $INSTALL_ZSH; then
    if install_zsh; then
      COMPLETED_STEPS+=("Zsh")
    else
      FAILED_STEPS+=("Zsh")
    fi
  fi

  if $INSTALL_ALL || $INSTALL_VIM; then
    if install_vim; then
      COMPLETED_STEPS+=("Vim")
    else
      FAILED_STEPS+=("Vim")
    fi
  fi

  if $INSTALL_ALL || $INSTALL_EMACS; then
    if install_emacs; then
      COMPLETED_STEPS+=("Emacs")
    else
      FAILED_STEPS+=("Emacs")
    fi
  fi

  if $INSTALL_ALL || $INSTALL_WEZTERM; then
    if install_wezterm; then
      COMPLETED_STEPS+=("WezTerm")
    else
      FAILED_STEPS+=("WezTerm")
    fi
  fi

  if $INSTALL_ALL || $INSTALL_BREW; then
    if install_brew; then
      COMPLETED_STEPS+=("Brew")
    else
      FAILED_STEPS+=("Brew")
    fi
  fi

  if $INSTALL_ALL || $INSTALL_PYTHON; then
    if install_python; then
      COMPLETED_STEPS+=("Python")
    else
      FAILED_STEPS+=("Python")
    fi
  fi

  if $INSTALL_ALL || $INSTALL_RUST; then
    if install_rust; then
      COMPLETED_STEPS+=("Rust")
    else
      FAILED_STEPS+=("Rust")
    fi
  fi

  if $INSTALL_ALL || $INSTALL_TMUX; then
    if install_tmux; then
      COMPLETED_STEPS+=("Tmux")
    else
      FAILED_STEPS+=("Tmux")
    fi
  fi

  if $INSTALL_ALL || $INSTALL_GIT; then
    if install_git; then
      COMPLETED_STEPS+=("Git")
    else
      FAILED_STEPS+=("Git")
    fi
  fi

  # EditorConfig: 默认随 --all 安装；也可单独 --editorconfig
  if $INSTALL_ALL || $INSTALL_EDITORCONFIG; then
    if install_editorconfig; then
      COMPLETED_STEPS+=("EditorConfig")
    else
      FAILED_STEPS+=("EditorConfig")
    fi
  fi

  # 最终验证
  final_check

  # 安装汇总报告
  echo_separator
  printf "${BOLD}${CYAN}安装汇总${RESET}\n"
  echo_separator
  printf "${GREEN}✅ 已完成 (%s): %s${RESET}\n" "${#COMPLETED_STEPS[@]}" "${COMPLETED_STEPS[*]:-无}"
  if [[ ${#FAILED_STEPS[@]} -gt 0 ]]; then
    printf "${RED}❌ 失败 (%s): %s${RESET}\n" "${#FAILED_STEPS[@]}" "${FAILED_STEPS[*]}"
    printf "${YELLOW}失败步骤不影响其他组件，可稍后重试: cd ~/.dotfiles && ./bootstrap.sh --<组件>${RESET}\n"
  fi
  echo_separator
}

main "$@"
