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
#   ./bootstrap.sh --wezterm  仅安装 WezTerm
#   ./bootstrap.sh --brew     仅安装 Brew 包
#   ./bootstrap.sh --python   仅配置 Python
#   ./bootstrap.sh --tmux     仅安装 Tmux
#   ./bootstrap.sh --git      仅安装 Git 配置

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
INSTALL_WEZTERM=false
INSTALL_BREW=false
INSTALL_PYTHON=false
INSTALL_TMUX=false
INSTALL_GIT=false

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

echo_step()    { echo -e "${BOLD}${BLUE}ℹ️  ${1}${RESET}"; }
echo_success() { echo -e "${GREEN}✅ ${1}${RESET}"; }
echo_warning() { echo -e "${YELLOW}⚠️  ${1}${RESET}"; }
echo_error()   { echo -e "${RED}❌ ${1}${RESET}"; }
echo_title() {
  echo -e "${BLUE}=============================================${RESET}"
  echo -e "${BOLD}${CYAN}${1}${RESET}"
  echo -e "${BLUE}=============================================${RESET}"
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
      --wezterm)  INSTALL_WEZTERM=true ;;
      --brew)     INSTALL_BREW=true ;;
      --python)   INSTALL_PYTHON=true ;;
      --tmux)     INSTALL_TMUX=true ;;
      --git)      INSTALL_GIT=true ;;
      -h|--help)
        head -20 "$0" | tail -15
        exit 0
        ;;
      *)
        echo_error "未知参数: $arg"
        echo "使用: $0 [--all|--zsh|--vim|--wezterm|--brew|--python|--tmux|--git]"
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

  # 询问是否设为默认 shell
  if [[ "$(getent passwd $USER | cut -d: -f7)" != "$(command -v zsh)" ]]; then
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

  # 1. 执行通用 Brewfile
  if [[ -f "${DOTFILES_DIR}/brew/Brewfile" ]]; then
    echo_step "执行 brew bundle（通用包）..."
    brew bundle --file="${DOTFILES_DIR}/brew/Brewfile" 2>>"${LOG_FILE}" || {
      echo_warning "部分通用包安装失败，请查看日志: ${LOG_FILE}"
    }
  fi

  # 2. 执行平台特定 Brewfile
  local platform_brewfile=""
  case "$(uname -s)" in
    Linux)  platform_brewfile="${DOTFILES_DIR}/brew/Brewfile.linux" ;;
    Darwin) platform_brewfile="${DOTFILES_DIR}/brew/Brewfile.macos" ;;
  esac
  if [[ -n "${platform_brewfile}" ]] && [[ -f "${platform_brewfile}" ]]; then
    echo_step "执行 brew bundle（平台包）..."
    brew bundle --file="${platform_brewfile}" 2>>"${LOG_FILE}" || {
      echo_warning "部分平台包安装失败，请查看日志: ${LOG_FILE}"
    }
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

  # 安装依赖
  if [[ -f "${DOTFILES_DIR}/python/requirements.txt" ]]; then
    pip3 install --user -r "${DOTFILES_DIR}/python/requirements.txt" 2>>"${LOG_FILE}" || {
      echo_warning "部分 Python 依赖安装失败"
    }
  fi

  echo_success "Python 环境配置完成"
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

  # 安装 TPM (Tmux Plugin Manager)
  local tpm_dir="${HOME}/.tmux/plugins/tpm"
  if [[ ! -d "${tpm_dir}" ]]; then
    echo_step "安装 Tmux Plugin Manager (TPM)..."
    if git clone --depth 1 https://github.com/tmux-plugins/tpm.git "${tpm_dir}" 2>>"${LOG_FILE}"; then
      echo_success "TPM 安装完成"
      echo "  安装插件: 打开 tmux 后按 前缀键 + I"
    else
      echo_warning "TPM 安装失败，可稍后手动安装"
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
  echo ""
  echo -e "${YELLOW}请在 ~/.gitconfig.local 中设置你的个人信息:${RESET}"
  echo "  [user]"
  echo "      name = Your Name"
  echo "      email = your@email.com"
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
    echo -e "${GREEN}✅ 所有配置安装成功！${RESET}"
    echo ""
    echo -e "${BOLD}下一步:${RESET}"
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

  # 前置检查
  check_prerequisites

  # 确保仓库存在
  clone_repo

  cd "${DOTFILES_DIR}"
  echo_success "当前目录: $(pwd)"
  echo ""

  # 安装组件
  if $INSTALL_ALL || $INSTALL_ZSH; then
    install_zsh
  fi

  if $INSTALL_ALL || $INSTALL_VIM; then
    install_vim
  fi

  if $INSTALL_ALL || $INSTALL_WEZTERM; then
    install_wezterm
  fi

  if $INSTALL_ALL || $INSTALL_BREW; then
    install_brew
  fi

  if $INSTALL_ALL || $INSTALL_PYTHON; then
    install_python
  fi

  if $INSTALL_ALL || $INSTALL_TMUX; then
    install_tmux
  fi

  if $INSTALL_ALL || $INSTALL_GIT; then
    install_git
  fi

  # EditorConfig 对所有开发者通用，总是安装
  install_editorconfig

  # 最终验证
  final_check
}

main "$@"
