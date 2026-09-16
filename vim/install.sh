#!/usr/bin/env bash

# ======================
# Vim 配置安装器
# ======================

set -euo pipefail
LOG_FILE="/tmp/vim_install_$(date +%Y%m%d_%H%M%S).log"

# 加载公共库（lib/common.sh 自带 output + symlink 的自动加载和 fallback）
# shellcheck source=/dev/null
source "$(dirname "$0")/_common.sh"

# vim-plug 镜像源（GitHub 官方优先，国内镜像降级）
if [[ -n "${NO_MIRROR:-}" ]]; then
  VIM_PLUG_MIRRORS=(
    "https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"
  )
else
  VIM_PLUG_MIRRORS=(
    "https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"
    "https://ghproxy.net/https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"
    "https://gh-proxy.com/https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"
  )
fi

# ======================
# 安装 Vim（含 sudo 检测）
# ======================
ensure_vim_installed() {
  if command -v vim > /dev/null 2>&1; then
    echo_success "Vim 已安装: $(vim --version | head -1)"
    return 0
  fi

  echo_warning "Vim 未安装"
  if command -v brew > /dev/null 2>&1; then
    echo_step "通过 brew 安装 Vim..."
    brew install vim 2>>"${LOG_FILE}" && echo_success "Vim 安装完成"
  elif command -v apt > /dev/null 2>&1; then
    if have_sudo; then
      echo_step "通过 apt 安装 Vim..."
      sudo apt install -y vim 2>>"${LOG_FILE}" && echo_success "Vim 安装完成"
    else
      echo_error "需要 sudo 权限安装 vim，请手动执行: sudo apt install -y vim"
      return 1
    fi
  elif command -v yum > /dev/null 2>&1; then
    if have_sudo; then
      echo_step "通过 yum 安装 Vim..."
      sudo yum install -y vim 2>>"${LOG_FILE}" && echo_success "Vim 安装完成"
    else
      echo_error "需要 sudo 权限安装 vim，请手动执行: sudo yum install -y vim"
      return 1
    fi
  else
    echo_warning "未识别包管理器，请手动安装 Vim"
  fi
}

# ======================
# 创建 .vimrc 链接
# ======================
create_vimrc_link() {
  echo_step "配置 .vimrc 符号链接..."

  local vimrc_src="${VIM_DIR}/.vimrc"
  local vimrc_dst="${HOME}/.vimrc"

  if [[ ! -f "${vimrc_src}" ]]; then
    echo_error "源文件不存在: ${vimrc_src}"
    return 1
  fi

  if [[ -L "${vimrc_dst}" ]]; then
    local current_target
    current_target=$(readlink "${vimrc_dst}")
    if [[ "${current_target}" == "${vimrc_src}" ]]; then
      echo_success ".vimrc 链接已存在且指向正确位置"
      return 0
    fi
    echo_warning "更新 .vimrc 链接..."
    rm -f "${vimrc_dst}"
  elif [[ -f "${vimrc_dst}" ]]; then
    echo_warning "发现现有 .vimrc，备份为 .vimrc.bak"
    mv "${vimrc_dst}" "${vimrc_dst}.bak"
  fi

  safe_symlink "${vimrc_src}" "${vimrc_dst}" || true
  echo_success ".vimrc 链接已创建"
}

# ======================
# 创建 NeoVim 适配入口（可选）
# 策略：不做符号链接（~/.vimrc 与 nvim init 路径无法直接 ln），
# 而是生成一个薄包装 init.vim，通过 runtimepath + source 复用 Vim 配置。
# ======================
create_nvim_link() {
  if ! command -v nvim > /dev/null 2>&1; then
    return 0
  fi

  echo_step "检测到 NeoVim，生成 init.vim 包装以复用 Vim 配置..."

  local nvim_config_dir="${HOME}/.config/nvim"
  local nvim_init="${nvim_config_dir}/init.vim"
  local vimrc_src="${VIM_DIR}/.vimrc"

  mkdir -p "${nvim_config_dir}"

  if [[ -L "${nvim_init}" ]]; then
    echo_warning "发现 init.vim 为符号链接，备份为 init.vim.bak"
    mv "${nvim_init}" "${nvim_init}.bak"
  elif [[ -f "${nvim_init}" ]]; then
    echo_warning "发现现有 init.vim，备份为 init.vim.bak"
    mv "${nvim_init}" "${nvim_init}.bak"
  fi

  # 路径在 Vim 脚本侧用 expand('~')/fnameescape() 求值，确保空格/特殊字符安全，不依赖 bash 引号
  cat > "${nvim_init}" <<'EOF'
" NeoVim 入口：复用 dotfiles Vim 配置
" 兼容性处理：NeoVim 默认 nocompatible
let s:dotfiles_vim = expand('~/.dotfiles/vim')
execute 'set runtimepath^=' . fnameescape(s:dotfiles_vim)
execute 'source ' . fnameescape(s:dotfiles_vim . '/.vimrc')
EOF
  echo_success "init.vim 包装已创建"
}

# ======================
# 创建缓存目录
# ======================
create_cache_dirs() {
  echo_step "创建 Vim 缓存目录..."

  mkdir -p "${HOME}/.cache/vim/undo"
  mkdir -p "${HOME}/.cache/vim/backup"
  mkdir -p "${HOME}/.cache/vim/swap"

  echo_success "缓存目录已创建"
}

# ======================
# 下载 vim-plug 到指定路径（多镜像回退）
# ======================
_download_vim_plug() {
  local plug_file="$1"
  local plug_dir
  plug_dir="$(dirname "${plug_file}")"
  mkdir -p "${plug_dir}"

  local url
  for url in "${VIM_PLUG_MIRRORS[@]}"; do
    echo_detail "尝试: ${url}"
    if curl -fLo "${plug_file}" --connect-timeout 15 --max-time 60 \
      "${url}" 2>>"${LOG_FILE}"; then
      echo_success "vim-plug 安装完成: ${plug_file}（来源: ${url}）"
      return 0
    fi
    echo_warning "此镜像失败，尝试下一个..."
  done

  return 1
}

# ======================
# 安装 vim-plug（Vim + Neovim）
# ======================
install_vim_plug() {
  echo_step "检查 vim-plug 插件管理器..."

  # --- Vim 路径 ---
  local vim_plug="${HOME}/.vim/autoload/plug.vim"
  local vim_plug_ok=true

  if [[ -f "${vim_plug}" ]]; then
    echo_success "vim-plug 已安装 (Vim): ${vim_plug}"
  else
    echo_step "安装 vim-plug (Vim)..."
    if _download_vim_plug "${vim_plug}"; then
      :
    else
      vim_plug_ok=false
      echo_error "vim-plug 安装失败 (Vim)，所有镜像均不可用"
      printf '%s\n' "  请手动执行:"
      printf '%s\n' "  curl -fLo ~/.vim/autoload/plug.vim --create-dirs \\"
      printf '%s\n' "    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"
    fi
  fi

  # --- Neovim 路径（独立安装，不依赖 Vim 的 autoload）---
  if command -v nvim > /dev/null 2>&1; then
    local nvim_plug="${HOME}/.local/share/nvim/site/autoload/plug.vim"

    if [[ -f "${nvim_plug}" ]]; then
      echo_success "vim-plug 已安装 (Neovim): ${nvim_plug}"
    else
      echo_step "安装 vim-plug (Neovim)..."
      if _download_vim_plug "${nvim_plug}"; then
        :
      else
        echo_error "vim-plug 安装失败 (Neovim)，所有镜像均不可用"
        printf '%s\n' "  请手动执行:"
        printf '%s\n' "  curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \\"
        printf '%s\n' "    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"
      fi
    fi
  fi

  if [[ "${vim_plug_ok}" == "true" ]]; then
    echo_warning "首次打开 Vim 时将自动安装插件"
  fi
}

# ======================
# 配置 coc.nvim npm 镜像（加速扩展安装）
# ======================
# coc.nvim 扩展从 npm registry 下载，默认无镜像
# 在 coc extensions 目录放置 .npmrc，仅影响 coc 扩展安装，不污染全局 npm
configure_coc_npm_mirror() {
  if [[ -n "${NO_MIRROR:-}" ]]; then
    return 0
  fi

  local coc_ext_dir="${HOME}/.config/coc/extensions"
  local npmrc_file="${coc_ext_dir}/.npmrc"

  if is_dry_run; then
    echo_detail "[dry-run] 将创建: ${npmrc_file}"
    return 0
  fi

  mkdir -p "${coc_ext_dir}" 2>/dev/null
  if [[ ! -f "${npmrc_file}" ]] || ! grep -q 'npmmirror' "${npmrc_file}" 2>/dev/null; then
    printf 'registry=https://registry.npmmirror.com\n' > "${npmrc_file}"
    echo_success "coc.nvim npm 镜像已配置 (npmmirror)"
  else
    echo_skip "coc.nvim npm 镜像已存在"
  fi
}

# ======================
# 主流程
# ======================
main() {
  echo_title "Vim 配置安装器"
  printf '安装日志: %s\n' "${LOG_FILE}"

  ensure_vim_installed

  echo_separator

  create_vimrc_link
  create_nvim_link
  create_cache_dirs
  install_vim_plug
  configure_coc_npm_mirror

  echo_separator
  printf "${GREEN}${CHECK} ${BOLD}Vim 配置安装完成！${RESET}\n"
  printf "${YELLOW}首次打开 Vim 将自动安装插件${RESET}\n"
  printf "${YELLOW}或手动执行: vim +PlugInstall +qa${RESET}\n"
}

main
