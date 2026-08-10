#!/usr/bin/env bash

# ======================
# Emacs 配置安装器
# ======================
#
# 功能:
#   1. 检查/安装 Emacs（通过包管理器）
#   2. 链接配置到 ~/.config/emacs/ 或 ~/.emacs.d/
#   3. 创建缓存目录
#   4. 首次启动自动安装包

set -euo pipefail

DOTFILES_ROOT="${HOME}/.dotfiles"
EMACS_DIR="${DOTFILES_ROOT}/emacs"
LOG_FILE="/tmp/dotfiles_emacs_install_$(date +%Y%m%d_%H%M%S).log"

# ======================
# 加载公共输出函数库
# ======================
_OUTPUT_LIB="${DOTFILES_ROOT}/lib/output.sh"
if [[ -f "${_OUTPUT_LIB}" ]]; then
  source "${_OUTPUT_LIB}"
else
  RED="\033[31m"; GREEN="\033[32m"; YELLOW="\033[33m"; BLUE="\033[34m"
  CYAN="\033[36m"; RESET="\033[0m"; BOLD="\033[1m"
  CHECK="✅"; INFO="ℹ️"; WARN="⚠️"; ERROR="❌"; ARROW="➡️"; SKIP="⏭️"
  SEPARATOR="${BLUE}=============================================${RESET}"
  echo_step()      { printf "${BOLD}${BLUE}${INFO} %s${RESET}\n"  "${1}"; }
  echo_success()   { printf "${GREEN}${CHECK} %s${RESET}\n"       "${1}"; }
  echo_warning()   { printf "${YELLOW}${WARN} %s${RESET}\n"       "${1}"; }
  echo_error()     { printf "${RED}${ERROR} %s${RESET}\n"         "${1}"; }
  echo_skip()      { printf "${CYAN}${SKIP} %s${RESET}\n"         "${1}"; }
  echo_detail()    { printf "${BLUE}  %s${RESET}\n"               "${1}"; }
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
# 检查/安装 Emacs
# ======================
install_emacs() {
  if command -v emacs > /dev/null 2>&1; then
    local emacs_version
    emacs_version="$(emacs --version 2>/dev/null | head -1)"
    echo_success "Emacs 已安装: ${emacs_version}"

    # 检查版本是否 >= 26（配置最低要求）
    local major_version
    major_version="$(emacs --version 2>/dev/null | head -1 | grep -o 'GNU Emacs [0-9]*' | grep -o '[0-9]*')"
    if [[ -n "${major_version}" ]] && [[ "${major_version}" -lt 26 ]]; then
      echo_warning "Emacs 版本 ${major_version} 低于 26，部分功能可能不可用"
      echo "  建议升级: brew install emacs 或从源码编译"
    fi
    return 0
  fi

  echo_step "安装 Emacs..."

  if command -v brew > /dev/null 2>&1; then
    brew install emacs 2>>"${LOG_FILE}" && echo_success "Emacs 安装完成（brew）"
  elif command -v apt > /dev/null 2>&1; then
    sudo apt update -qq && sudo apt install -y emacs 2>>"${LOG_FILE}" && echo_success "Emacs 安装完成（apt）"
  elif command -v dnf > /dev/null 2>&1; then
    sudo dnf install -y emacs 2>>"${LOG_FILE}" && echo_success "Emacs 安装完成（dnf）"
  elif command -v pacman > /dev/null 2>&1; then
    sudo pacman -S --noconfirm emacs 2>>"${LOG_FILE}" && echo_success "Emacs 安装完成（pacman）"
  else
    echo_error "无法自动安装 Emacs，请手动安装"
    echo "  macOS:  brew install emacs"
    echo "  Ubuntu: sudo apt install emacs"
    echo "  Arch:   sudo pacman -S emacs"
    return 1
  fi
}

# ======================
# 链接配置文件
# ======================
link_configs() {
  echo_step "链接 Emacs 配置..."

  # 优先使用 XDG 路径 ~/.config/emacs/（Emacs 27+）
  # 回退到传统路径 ~/.emacs.d/
  local emacs_config_dir=""

  # 检查现有配置
  if [[ -d "${HOME}/.config/emacs" ]]; then
    emacs_config_dir="${HOME}/.config/emacs"
  elif [[ -d "${HOME}/.emacs.d" ]]; then
    emacs_config_dir="${HOME}/.emacs.d"
  else
    # 默认使用 XDG 路径
    emacs_config_dir="${HOME}/.config/emacs"
    mkdir -p "${emacs_config_dir}"
  fi

  # 如果是普通目录（非符号链接），备份后替换
  if [[ -d "${emacs_config_dir}" && ! -L "${emacs_config_dir}" ]]; then
    # 检查是否已有 init.el（非我们的）
    if [[ -f "${emacs_config_dir}/init.el" ]] && [[ ! -L "${emacs_config_dir}/init.el" ]]; then
      local backup_dir="${emacs_config_dir}.bak.$(date +%Y%m%d_%H%M%S)"
      mv "${emacs_config_dir}" "${backup_dir}"
      echo_warning "已备份旧配置到: ${backup_dir}"
      mkdir -p "${emacs_config_dir}"
    fi
  fi

  # 链接顶层配置文件
  local top_files=(
    "early-init.el"
    "init.el"
    ".dir-locals.el"
    ".agignore"
  )

  for file in "${top_files[@]}"; do
    local src="${EMACS_DIR}/${file}"
    local dst="${emacs_config_dir}/${file}"

    if [[ ! -f "${src}" ]]; then
      continue
    fi

    if [[ -L "${dst}" ]]; then
      rm -f "${dst}"
    elif [[ -f "${dst}" ]]; then
      mv "${dst}" "${dst}.bak"
      echo_warning "已备份: ${file} -> ${file}.bak"
    fi

    safe_symlink "${src}" "${dst}" || true
  done

  # 链接 lisp/ 目录
  local lisp_src="${EMACS_DIR}/lisp"
  local lisp_dst="${emacs_config_dir}/lisp"

  if [[ -L "${lisp_dst}" ]]; then
    rm -f "${lisp_dst}"
  elif [[ -d "${lisp_dst}" ]]; then
    mv "${lisp_dst}" "${lisp_dst}.bak"
    echo_warning "已备份旧 lisp/ 目录"
  fi
  safe_symlink "${lisp_src}" "${lisp_dst}" || true

  # 链接 site-lisp/ 目录
  local site_lisp_src="${EMACS_DIR}/site-lisp"
  local site_lisp_dst="${emacs_config_dir}/site-lisp"

  if [[ -L "${site_lisp_dst}" ]]; then
    rm -f "${site_lisp_dst}"
  elif [[ -d "${site_lisp_dst}" ]]; then
    mv "${site_lisp_dst}" "${site_lisp_dst}.bak"
    echo_warning "已备份旧 site-lisp/ 目录"
  fi
  safe_symlink "${site_lisp_src}" "${site_lisp_dst}" || true

  # 链接 ede-projects.el（如果存在）
  if [[ -f "${EMACS_DIR}/ede-projects.el" ]]; then
    safe_symlink "${EMACS_DIR}/ede-projects.el" "${emacs_config_dir}/ede-projects.el" || true
  fi

  echo_success "配置文件已链接到 ${emacs_config_dir}"
}

# ======================
# 创建缓存目录
# ======================
create_cache_dirs() {
  echo_step "创建缓存目录..."

  local dirs=(
    "${HOME}/.cache/emacs/backup"
    "${HOME}/.cache/emacs/auto-save"
    "${HOME}/.cache/emacs/url"
  )

  for dir in "${dirs[@]}"; do
    mkdir -p "${dir}" 2>/dev/null || true
  done

  echo_success "缓存目录已创建"
}

# ======================
# 首次启动（自动安装包）
# ======================
bootstrap_packages() {
  if ! command -v emacs > /dev/null 2>&1; then
    echo_warning "Emacs 不可用，跳过包安装"
    return 0
  fi

  echo_step "首次启动 Emacs（更新包索引）..."
  echo "  日志: ${LOG_FILE}"

  # 批量模式更新包索引
  if emacs --batch --eval "(package-refresh-contents)" 2>>"${LOG_FILE}"; then
    echo_success "包索引已更新"
  else
    echo_warning "包索引更新失败，Emacs 首次启动时会自动安装"
    echo "  可手动执行: emacs --batch --eval \"(package-refresh-contents)\""
  fi
}

# ======================
# 主流程
# ======================
main() {
  echo_title "Emacs 配置安装器"
  echo "安装日志: ${LOG_FILE}"
  echo ""

  # 1. 安装 Emacs
  install_emacs

  echo_separator

  # 2. 链接配置
  link_configs

  echo_separator

  # 3. 创建缓存目录
  create_cache_dirs

  echo_separator

  # 4. 首次启动安装包
  bootstrap_packages

  echo_title "Emacs 配置安装完成"
  printf "${GREEN}${CHECK} ${BOLD}Emacs 配置完成！${RESET}\n"
  echo ""
  printf "${BOLD}验证:${RESET}\n"
  echo "  emacs --version"
  echo "  emacs &"
  echo ""
  printf "${BOLD}首次启动:${RESET}\n"
  echo "  Emacs 会自动安装配置中声明的所有包"
  echo "  可能需要几分钟，请耐心等待"
  echo ""
  printf "${BOLD}配置文件位置:${RESET}\n"
  echo "  ~/.config/emacs/init.el          # 主入口"
  echo "  ~/.config/emacs/early-init.el    # 早期初始化"
  echo "  ~/.config/emacs/lisp/            # 模块化配置（init-*.el）"
  echo "  ~/.config/emacs/site-lisp/       # 本地扩展"
  echo "  ~/.config/emacs/lisp/init-local.el  # 本地自定义（可选）"
  echo ""
  echo "安装日志: ${LOG_FILE}"
  echo_separator
}

main
