#!/usr/bin/env bash

# ======================
# Rust 开发环境安装器
# ======================
#
# 功能:
#   1. 安装 rustup（Rust 工具链管理器）
#   2. 安装 stable 工具链及常用组件
#   3. 配置 cargo 镜像源（国内加速）
#   4. 链接 rustfmt / clippy 配置
#   5. 安装常用 cargo 扩展工具

set -euo pipefail

DOTFILES_ROOT="${HOME}/.dotfiles"
RUST_DIR="${DOTFILES_ROOT}/rust"
LOG_FILE="/tmp/dotfiles_rust_install_$(date +%Y%m%d_%H%M%S).log"

# ======================
# 加载公共输出函数库
# ======================
_OUTPUT_LIB="${DOTFILES_ROOT}/zsh/lib/output.sh"
if [[ -f "${_OUTPUT_LIB}" ]]; then
  # shellcheck source=/dev/null
  source "${_OUTPUT_LIB}"
else
  RED="\033[31m"; GREEN="\033[32m"; YELLOW="\033[33m"; BLUE="\033[34m"
  CYAN="\033[36m"; WHITE="\033[37m"; RESET="\033[0m"; BOLD="\033[1m"
  CHECK="✅"; INFO="ℹ️"; WARN="⚠️"; ERROR="❌"; ARROW="➡️"
  SEPARATOR="${BLUE}=============================================${RESET}"
  echo_step()      { printf "${BOLD}${BLUE}${INFO} %s${RESET}\n"  "${1}"; }
  echo_success()   { printf "${GREEN}${CHECK} %s${RESET}\n"        "${1}"; }
  echo_warning()   { printf "${YELLOW}${WARN} %s${RESET}\n"        "${1}"; }
  echo_error()     { printf "${RED}${ERROR} %s${RESET}\n"          "${1}"; }
  echo_separator() { printf '%b\n' "${SEPARATOR}"; }
  echo_title() {
    echo_separator
    printf "${BOLD}${CYAN}%s${RESET}\n" "${1}"
    echo_separator
  }
fi

# ======================
# 安装 rustup（Rust 工具链管理器）
# ======================
install_rustup() {
  if command -v rustup > /dev/null 2>&1; then
    echo_success "rustup 已安装: $(rustup --version)"
    return 0
  fi

  if command -v rustc > /dev/null 2>&1; then
    local rust_version
    rust_version="$(rustc --version)"
    echo_warning "检测到已有 Rust 安装（无 rustup）: ${rust_version}"
    echo "  当前通过 $(command -v rustc) 提供"
    echo "  建议使用 rustup 管理工具链以获得更好的版本控制"
    echo ""
    echo "  迁移方式（推荐）:"
    echo "    1. 卸载 brew 版本: brew uninstall rust"
    echo "    2. 安装 rustup:    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    echo "    3. 重新运行:       ./bootstrap.sh --rust"
    echo ""
    echo "  继续使用当前安装，跳过 rustup 安装"
    return 0
  fi

  echo_step "安装 rustup..."

  # 通过官方脚本安装
  local rustup_url="https://sh.rustup.rs"
  local tmp_script
  tmp_script="$(mktemp)"
  trap 'rm -f "${tmp_script}"' EXIT RETURN

  if ! curl -fsSL "${rustup_url}" -o "${tmp_script}" 2>>"${LOG_FILE}"; then
    echo_error "无法下载 rustup 安装脚本"
    echo "  手动安装: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    return 1
  fi

  # 非交互式安装
  if sh "${tmp_script}" -y --default-toolchain stable 2>>"${LOG_FILE}"; then
    echo_success "rustup 安装完成"
    # 加载环境变量
    # shellcheck source=/dev/null
    source "${HOME}/.cargo/env" 2>/dev/null || true
  else
    echo_error "rustup 安装失败，请查看日志: ${LOG_FILE}"
    return 1
  fi
}

# ======================
# 安装工具链组件
# ======================
install_components() {
  if command -v rustup > /dev/null 2>&1; then
    # rustup 模式：使用 rustup component add
    echo_step "安装 Rust 工具链组件（rustup 模式）..."

    local components=("rustfmt" "clippy" "rust-src")
    for comp in "${components[@]}"; do
      if rustup component add "${comp}" > /dev/null 2>&1; then
        echo_success "组件已安装: ${comp}"
      else
        echo_warning "组件安装失败: ${comp}"
      fi
    done

    rustup update stable > /dev/null 2>&1 || true
    echo_success "Rust 工具链已更新（rustup）"
  elif command -v rustc > /dev/null 2>&1; then
    # 非 rustup 模式（如 Homebrew 安装）：检查常见组件是否已包含
    echo_step "检查 Rust 组件（非 rustup 模式）..."

    # rustfmt 和 clippy 通常随 brew rust 一起安装
    local missing_components=()
    for tool in rustfmt clippy; do
      if command -v "${tool}" > /dev/null 2>&1; then
        echo_success "${tool} 已可用"
      else
        missing_components+=("${tool}")
        echo_warning "${tool} 不可用（brew rust 通常包含此组件）"
      fi
    done

    if [[ ${#missing_components[@]} -gt 0 ]]; then
      echo "  安装缺失组件:"
      echo "    brew install rustfmt clippy"
      echo "    或: rustup component add ${missing_components[*]}"
    fi

    # rust-analyzer 需要单独安装
    if ! command -v rust-analyzer > /dev/null 2>&1; then
      echo_step "安装 rust-analyzer..."
      if command -v cargo > /dev/null 2>&1; then
        cargo install rust-analyzer > /dev/null 2>&1 || {
          echo_warning "rust-analyzer 安装失败"
          echo "  可通过 brew 安装: brew install rust-analyzer"
        }
      fi
    else
      echo_success "rust-analyzer 已可用"
    fi
  else
    echo_warning "Rust 不可用，跳过组件安装"
  fi
}

# ======================
# 链接配置文件
# ======================
link_configs() {
  echo_step "链接 Rust 配置文件..."

  # cargo config
  local cargo_dir="${HOME}/.cargo"
  mkdir -p "${cargo_dir}"

  local cargo_config="${cargo_dir}/config.toml"
  if [[ ! -L "${cargo_config}" ]] && [[ ! -f "${cargo_config}" ]]; then
    if ln -sf "${RUST_DIR}/config.toml" "${cargo_config}" 2>/dev/null; then
      echo_success "已链接 ~/.cargo/config.toml"
    else
      echo_warning "无法链接 ~/.cargo/config.toml（权限或环境限制）"
    fi
  else
    echo_warning "~/.cargo/config.toml 已存在，跳过"
  fi

  # rustfmt 配置（全局）
  local rustfmt_config="${HOME}/.rustfmt.toml"
  if [[ ! -L "${rustfmt_config}" ]] && [[ ! -f "${rustfmt_config}" ]]; then
    if ln -sf "${RUST_DIR}/rustfmt.toml" "${rustfmt_config}" 2>/dev/null; then
      echo_success "已链接 ~/.rustfmt.toml"
    else
      echo_warning "无法链接 ~/.rustfmt.toml（权限或环境限制）"
    fi
  else
    echo_warning "~/.rustfmt.toml 已存在，跳过"
  fi

  # clippy 配置（全局）
  local clippy_config="${HOME}/.clippy.toml"
  if [[ ! -L "${clippy_config}" ]] && [[ ! -f "${clippy_config}" ]]; then
    if ln -sf "${RUST_DIR}/clippy.toml" "${clippy_config}" 2>/dev/null; then
      echo_success "已链接 ~/.clippy.toml"
    else
      echo_warning "无法链接 ~/.clippy.toml（权限或环境限制）"
    fi
  else
    echo_warning "~/.clippy.toml 已存在，跳过"
  fi
}

# ======================
# 安装常用 cargo 扩展工具
# ======================
install_cargo_tools() {
  if ! command -v cargo > /dev/null 2>&1; then
    echo_warning "cargo 不可用，跳过扩展工具安装"
    return 0
  fi

  echo_step "安装常用 cargo 扩展工具..."

  # 常用工具列表（排除已内置功能：cargo-tree 自 1.44、cargo-add 自 1.62）
  local tools=(
    "cargo-watch"         # 文件变化自动重新编译
    "cargo-outdated"      # 检查依赖更新
    "cargo-audit"         # 安全漏洞检查
    "cargo-expand"        # 宏展开
    "cargo-binstall"      # 预编译二进制安装
  )

  for tool in "${tools[@]}"; do
    printf "${BOLD}${CYAN}${ARROW} 安装 %s...${RESET}\n" "${tool}"
    if cargo install "${tool}" > /dev/null 2>&1; then
      echo_success "${tool} 安装完成"
    else
      echo_warning "${tool} 安装失败（可能需要 nightly 或网络问题）"
    fi
  done
}

# ======================
# 配置环境变量
# ======================
setup_env() {
  echo_step "配置 Rust 环境变量..."

  # 清理可能存在的无效 cargo/env 引用（Homebrew 安装时 ~/.cargo/env 不存在）
  local zshrc_local="${HOME}/.zshrc.local"
  if [[ -f "${zshrc_local}" ]]; then
    if grep -q 'source.*\.cargo/env' "${zshrc_local}" 2>/dev/null; then
      # 移除无效行（使用临时文件，兼容 macOS/Linux）
      local tmp_file
      tmp_file="$(mktemp)"
      grep -v 'source.*\.cargo/env' "${zshrc_local}" | grep -v '# Rust/cargo 环境' > "${tmp_file}" 2>/dev/null || true
      mv "${tmp_file}" "${zshrc_local}" 2>/dev/null || cp "${tmp_file}" "${zshrc_local}" 2>/dev/null
      rm -f "${tmp_file}"
      # 文件为空则删除
      if [[ ! -s "${zshrc_local}" ]]; then
        rm -f "${zshrc_local}" 2>/dev/null
      fi
      echo_warning "已清理无效的 cargo/env 引用（Homebrew 安装无需此配置）"
    fi
  fi

  # rustup 模式：~/.cargo/env 文件存在才添加
  local cargo_env="${HOME}/.cargo/env"
  if [[ -f "${cargo_env}" ]]; then
    local cargo_env_line='source "$HOME/.cargo/env"'

    # 检查 .zshenv 中是否已包含
    local zshenv="${HOME}/.zshenv"
    if [[ -f "${zshenv}" ]] && grep -q '.cargo/env' "${zshenv}" 2>/dev/null; then
      echo_success "环境变量已配置（.zshenv）"
      return 0
    fi

    # 检查 .zshrc 中是否已包含
    local zshrc="${HOME}/.zshrc"
    if [[ -f "${zshrc}" ]] && grep -q '.cargo/env' "${zshrc}" 2>/dev/null; then
      echo_success "环境变量已配置（.zshrc）"
      return 0
    fi

    # 添加到 .zshrc.local 或 .zshenv
    local target_file=""
    if [[ -f "${zshrc}" ]]; then
      if grep -q 'dotfiles' "${zshrc}" 2>/dev/null; then
        target_file="${zshrc_local}"
      else
        target_file="${zshrc}"
      fi
    else
      target_file="${zshenv}"
    fi

    echo_step "添加 cargo env 到 ${target_file}..."
    echo '# Rust/cargo 环境（由 rustup 安装）' >> "${target_file}"
    echo "${cargo_env_line}" >> "${target_file}"
    echo_success "已添加 cargo 环境变量到 ${target_file}"
  elif command -v cargo > /dev/null 2>&1; then
    # Homebrew 模式：cargo 已在 PATH 中，无需额外配置
    echo_success "cargo 已在 PATH 中（$(command -v cargo)），无需额外配置"
  else
    echo_warning "cargo 不可用，请先安装 Rust"
  fi
}

# ======================
# 主流程
# ======================
main() {
  echo_title "Rust 开发环境安装器"
  echo "安装日志: ${LOG_FILE}"
  echo ""

  # 1. 安装 rustup
  install_rustup

  echo_separator

  # 2. 安装组件
  install_components

  echo_separator

  # 3. 链接配置文件
  link_configs

  echo_separator

  # 4. 安装 cargo 扩展工具
  install_cargo_tools

  echo_separator

  # 5. 环境变量检查
  setup_env

  echo_title "Rust 环境安装完成"
  printf "${GREEN}${CHECK} ${BOLD}Rust 开发环境配置完成！${RESET}\n"
  echo ""
  printf "${BOLD}验证:${RESET}\n"
  echo "  rustc --version"
  echo "  cargo --version"
  echo "  rustup --version"
  echo ""
  printf "${BOLD}常用命令:${RESET}\n"
  echo "  cargo new my-project    # 创建新项目"
  echo "  cargo build              # 编译"
  echo "  cargo run                # 运行"
  echo "  cargo test               # 测试"
  echo "  cargo clippy             # 代码检查"
  echo "  cargo fmt                # 格式化"
  echo "  cargo watch -x run       # 文件变化自动运行"
  echo ""
  echo "安装日志: ${LOG_FILE}"
  echo_separator
}

main
