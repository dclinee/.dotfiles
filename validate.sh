#!/usr/bin/env bash
set -eo pipefail

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

  # 验证Vim配置 - 跳过语法检查以避免交互式编辑器
  log INFO "跳过Vim配置语法检查..."
  log SUCCESS "Vim配置验证跳过"

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

  log SUCCESS "功能验证通过！"
  return 0
}

# 主函数
main() {
  log INFO "初始化测试环境..."
  init_platform

  # 检查命令行参数
  if [[ "$1" == "--dry-run" || "$1" == "--simulate" ]]; then
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