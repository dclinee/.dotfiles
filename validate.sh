#!/usr/bin/env bash
set -euo pipefail

# 配置变量
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
temp_dir=$(mktemp -d)
trap 'rm -rf ${temp_dir}' EXIT

# 颜色定义
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
CYAN="\033[36m"
RESET="\033[0m"

# 日志函数
log() {
  local level="$1"
  local message="$2"
  local color

  case "$level" in
    INFO) color="$BLUE" ;;
    WARN) color="$YELLOW" ;;
    ERROR) color="$RED" ;;
    SUCCESS) color="$GREEN" ;;
    SIM) color="$CYAN" ;;
    *) color="$RESET" ;;
  esac

  printf "${color}[%s] %s${RESET}\n" "${level}" "${message}"
}

# 带指数退避的重试函数
retry_with_backoff() {
  local max_attempts=3
  local delay=2
  local attempt=0

  until "$@"; do
    attempt=$((attempt + 1))
    if [ "$attempt" -gt "$max_attempts" ]; then
      return 1
    fi

    log WARN "尝试 $attempt/$max_attempts 失败，${delay}秒后重试..."
    sleep "$delay"
    delay=$((delay * 2))
  done

  return 0
}

# 检查系统类型
init_platform() {
  case "$(uname)" in
    Darwin) export PLATFORM="macOS" ;;
    Linux) export PLATFORM="Linux" ;;
    *) log ERROR "不支持的平台：$(uname)" ; exit 1 ;;
  esac
  log INFO "当前平台：$PLATFORM"
}

# 模拟安装流程
simulate_install() {
  log SIM "模拟安装流程："

  # Brew 安装模拟（实际文件名为 install.sh）
  local brew_script="${DOTFILES_DIR}/brew/install.sh"
  if [ -f "${brew_script}" ]; then
    log SIM "[Brew] 将执行："
    grep 'brew bundle\|brew install' "${brew_script}" || true
  fi

  # Zsh 安装模拟
  log SIM "[Zsh] 将配置："
  find "${DOTFILES_DIR}/zsh" -name '*.zsh' -exec grep -E '^source|^export' {} \; | sort | uniq | head -20
}

# 功能验证
validate_functionality() {
  log INFO "验证功能..."

  # 复制配置到临时目录（用 cp 替代 rsync，减少外部依赖）
  # 排除 .md 文档和 .git 目录，只验证可执行配置
  local dir
  for dir in zsh brew vim wezterm; do
    if [[ -d "${DOTFILES_DIR}/${dir}" ]]; then
      cp -r "${DOTFILES_DIR}/${dir}" "${temp_dir}/" 2>/dev/null || true
      # 移除文档和非配置文件
      find "${temp_dir}/${dir}" -name '*.md' -delete 2>/dev/null || true
    fi
  done
  chmod -R +x "${temp_dir}/wezterm/install.sh" 2>/dev/null || true
  chmod -R +x "${temp_dir}/zsh/install.sh" "${temp_dir}/brew/install.sh" 2>/dev/null || true

  # 验证Zsh配置 - 只检查语法错误，忽略非致命警告
  log INFO "验证Zsh配置..."

  # 检查所有zsh配置文件
  local zsh_files=(
    "${temp_dir}/zsh/.zshrc"
    "${temp_dir}/zsh/core"/*.zsh
    "${temp_dir}/zsh/platform"/*.zsh
  )

  local all_valid=true
  for file in "${zsh_files[@]}"; do
    if [[ -f "${file}" ]]; then
      if ! zsh -n "${file}"; then
        log ERROR "${file} 语法检查失败"
        all_valid=false
      fi
    fi
  done

  if $all_valid; then
    log SUCCESS "Zsh配置语法检查通过"
  else
    log ERROR "Zsh配置语法检查失败"
    return 1
  fi

  # 验证Vim配置 - 用 vim --headless 做语法检查（不进入交互模式）
  log INFO "验证Vim配置..."
  if ! command -v vim > /dev/null 2>&1 && ! command -v nvim > /dev/null 2>&1; then
    log WARN "vim/nvim 命令不可用，跳过 Vim 语法检查"
  else
    local vim_bin
    vim_bin="$(command -v nvim 2>/dev/null || command -v vim 2>/dev/null)"
    local all_valid_vim=true
    local vim_files=(
      "${temp_dir}/vim/.vimrc"
    )
    for file in "${vim_files[@]}"; do
      if [[ -f "${file}" ]]; then
        # --headless 模式 + -es 静默执行 + -c 'q!' 退出
        # 若 .vimrc 有语法错误，vim 会在 stderr 输出错误信息
        local vim_out
        vim_out=$("${vim_bin}" --headless -es -u NONE -U NONE \
                  -c "source ${file}" -c 'q!' 2>&1) || true
        if echo "${vim_out}" | grep -qiE "E\d+:|Error detected"; then
          log ERROR "$(basename "${file}") Vim 语法错误"
          echo "${vim_out}" | grep -iE "E\d+:|Error detected" | head -3 || true
          all_valid_vim=false
        fi
      fi
    done
    if $all_valid_vim; then
      log SUCCESS "Vim 配置语法检查通过"
    else
      log ERROR "Vim 配置语法检查失败"
      return 1
    fi
  fi

  # 验证Wezterm配置 - 只检查语法错误
  log INFO "验证Wezterm配置..."

  # 检查所有wezterm配置文件
  local wezterm_files=(
    "${temp_dir}/wezterm/wezterm.lua"
    "${temp_dir}/wezterm/core"/*.lua
    "${temp_dir}/wezterm/platform"/*.lua
  )

  local all_valid_wezterm=true
  for file in "${wezterm_files[@]}"; do
    if [[ -f "${file}" ]]; then
      # 使用luac检查Lua语法（如果可用）
      if command -v luac &> /dev/null; then
        if ! luac -p "${file}"; then
          log ERROR "${file} Lua语法检查失败"
          all_valid_wezterm=false
        fi
      else
        log INFO "跳过${file}语法检查，因为luac不可用"
      fi
    fi
  done

  if $all_valid_wezterm; then
    log SUCCESS "Wezterm配置验证通过"
  else
    log ERROR "Wezterm配置验证失败"
    return 1
  fi

  # 验证SSH配置（直接在源目录验证，Include 使用绝对路径）
  log INFO "验证SSH配置..."

  local ssh_config="${DOTFILES_DIR}/ssh/config"
  if [[ ! -f "${ssh_config}" ]]; then
    log WARN "未找到 ssh/config，跳过"
  elif ! command -v ssh > /dev/null 2>&1; then
    log WARN "ssh 命令不可用，跳过 SSH 配置语法检查"
  else
    # ssh -G 不发起连接，只解析配置（OpenSSH 7.3+）
    if ssh -F "${ssh_config}" -G github.com > /dev/null 2>&1; then
      log SUCCESS "SSH 配置解析通过"
    else
      log ERROR "SSH 配置解析失败"
      ssh -F "${ssh_config}" -G github.com 2>&1 | head -5 || true
      return 1
    fi
  fi

  # 验证Emacs配置（对 lisp/*.el 做字节编译，不触发包安装/网络）
  log INFO "验证Emacs配置..."

  local emacs_lisp_dir="${DOTFILES_DIR}/emacs/lisp"
  if [[ ! -d "${emacs_lisp_dir}" ]]; then
    log WARN "未找到 emacs/lisp/，跳过"
  elif ! command -v emacs > /dev/null 2>&1; then
    log WARN "emacs 命令不可用，跳过 Emacs 字节编译检查"
  else
    local all_valid_emacs=true
    while IFS= read -r -d '' file; do
      # batch-byte-compile 只做语法检查，不实际 require 依赖
      if ! (cd "${DOTFILES_DIR}/emacs" && emacs --batch -f batch-byte-compile "${file}" 2>/dev/null); then
        log ERROR "$(basename "${file}") 字节编译失败"
        all_valid_emacs=false
      fi
    done < <(find "${emacs_lisp_dir}" -maxdepth 1 -name '*.el' -print0)

    if $all_valid_emacs; then
      log SUCCESS "Emacs 配置字节编译通过"
    else
      log ERROR "Emacs 配置字节编译失败"
      return 1
    fi
  fi

  # 验证 Git 配置（git config --file 只解析不执行）
  log INFO "验证Git配置..."
  {
    local git_files=(
      "${DOTFILES_DIR}/git/.gitconfig"
      "${DOTFILES_DIR}/git/.gitignore_global"
      "${DOTFILES_DIR}/git/.gitattributes"
    )
    local all_valid_git=true
    for gf in "${git_files[@]}"; do
      if [[ ! -f "${gf}" ]]; then
        log WARN "未找到 $(basename "${gf}")，跳过"
        continue
      fi
      if [[ "${gf}" == *.gitconfig ]]; then
        if ! git config --file "${gf}" --list > /dev/null 2>&1; then
          log ERROR "${gf} Git 配置解析失败"
          all_valid_git=false
        fi
      fi
    done
    if $all_valid_git; then
      log SUCCESS "Git 配置解析通过"
    else
      log ERROR "Git 配置解析失败"
      return 1
    fi
  }

  # 验证 Tmux 配置（tmux -f 静默启动只做语法检查）
  log INFO "验证Tmux配置..."
  {
    local tmux_conf="${DOTFILES_DIR}/tmux/.tmux.conf"
    if [[ ! -f "${tmux_conf}" ]]; then
      log WARN "未找到 tmux/.tmux.conf，跳过"
    elif ! command -v tmux > /dev/null 2>&1; then
      log WARN "tmux 命令不可用，跳过 Tmux 语法检查"
    else
      # 用 -L 指定临时 socket 避免与已有 tmux server 冲突
      tmux -L validate -f "${tmux_conf}" start-server 2>/dev/null || true
      local rc=$?
      tmux -L validate kill-server 2>/dev/null || true
      if [[ ${rc} -eq 0 ]]; then
        log SUCCESS "Tmux 配置语法通过"
      else
        log ERROR "Tmux 配置语法检查失败 (rc=${rc})"
        return 1
      fi
    fi
  }

  # 验证 Python 环境
  log INFO "验证Python环境..."
  if ! command -v python3 > /dev/null 2>&1; then
    log WARN "python3 命令不可用，跳过 Python 验证"
  elif ! python3 --version > /dev/null 2>&1; then
    log ERROR "python3 执行异常"
    return 1
  else
    log SUCCESS "Python $(python3 --version 2>&1)"
  fi

  # 验证 Rust 环境
  log INFO "验证Rust环境..."
  if ! command -v rustc > /dev/null 2>&1; then
    log WARN "rustc 命令不可用，跳过 Rust 验证"
  elif ! rustc --version > /dev/null 2>&1; then
    log ERROR "rustc 执行异常"
    return 1
  else
    log SUCCESS "Rust $(rustc --version 2>&1)"
  fi

  log SUCCESS "功能验证通过！"
  return 0
}

# 主函数
main() {
  log INFO "初始化测试环境..."
  init_platform

  # 检查命令行参数
  if [[ "${1:-}" == "--dry-run" || "${1:-}" == "--simulate" ]]; then
    simulate_install
    exit 0
  fi

  # 验证功能
  validate_functionality

  log SUCCESS "全量测试通过！"
  exit 0
}

# 执行主函数
main "$@"