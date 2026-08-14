#!/usr/bin/env bash

# ======================
# Rust 开发环境安装器（部署主入口）
# ======================
#
# 功能:
#   1. 安装 rustup（Rust 工具链管理器）
#   2. 安装 stable 工具链及常用组件
#   3. 配置 cargo 镜像源（国内加速）
#   4. 链接 rustfmt / clippy 配置
#   5. 安装常用 cargo 扩展工具（读取 tools.list）

set -euo pipefail

# 加载公共库与工具函数
# shellcheck source=/dev/null
source "$(dirname "$0")/_common.sh"

LOG_FILE="$(mktemp -t dotfiles_rust_install_XXXXXX.log 2>/dev/null || mktemp)"

# ======================
# 安装 rustup（Rust 工具链管理器）
# ======================
install_rustup() {
  if has_rustup; then
    echo_success "rustup 已安装: $(rustup --version 2>&1 | head -1)"
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

  local rustup_url="https://sh.rustup.rs"
  local tmp_script
  tmp_script="$(mktemp)"
  trap "rm -f '${tmp_script}'" EXIT RETURN

  # SJTU 镜像加速（受 NO_MIRROR 控制）
  if [[ -z "${NO_MIRROR:-}" ]]; then
    export RUSTUP_DIST_SERVER="https://mirrors.sjtug.sjtu.edu.cn/rust-static"
    export RUSTUP_UPDATE_ROOT="https://mirrors.sjtug.sjtu.edu.cn/rust-static/rustup"
  fi

  if ! curl --proto '=https' --tlsv1.2 -fsSL --connect-timeout 15 --max-time 120 "${rustup_url}" -o "${tmp_script}" 2>>"${LOG_FILE}"; then
    echo_error "无法下载 rustup 安装脚本"
    echo "  手动安装: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    rm -f "${tmp_script}"; trap - EXIT RETURN
    return 1
  fi

  # 安全检查: 文件非空且以 shebang 开头
  if [[ ! -s "${tmp_script}" ]]; then
    echo_error "下载的 rustup 脚本为空"
    rm -f "${tmp_script}"; trap - EXIT RETURN
    return 1
  fi
  local _rustup_first_line
  _rustup_first_line="$(head -1 "${tmp_script}")"
  if [[ ! "${_rustup_first_line}" =~ ^#! ]]; then
    echo_error "下载的文件不是 shell 脚本（首行: ${_rustup_first_line}）"
    rm -f "${tmp_script}"; trap - EXIT RETURN
    return 1
  fi

  if sh "${tmp_script}" -y --default-toolchain stable 2>>"${LOG_FILE}"; then
    echo_success "rustup 安装完成"
    # shellcheck source=/dev/null
    source "${HOME}/.cargo/env" 2>/dev/null || true
    if ! command -v cargo > /dev/null 2>&1; then
      echo_warning "cargo 不在 PATH 中，请手动: source ~/.cargo/env"
    fi
  else
    echo_error "rustup 安装失败，请查看日志: ${LOG_FILE}"
    rm -f "${tmp_script}"; trap - EXIT RETURN
    return 1
  fi

  rm -f "${tmp_script}"; trap - EXIT RETURN
}

# ======================
# 安装工具链组件
# ======================
install_components() {
  if has_rustup; then
    echo_step "安装 Rust 工具链组件（rustup 模式）..."

    local components=("rustfmt" "clippy" "rust-src" "rust-analyzer")
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
    echo_step "检查 Rust 组件（非 rustup 模式）..."

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

    if ! command -v rust-analyzer > /dev/null 2>&1; then
      echo_step "安装 rust-analyzer..."
      if command -v brew > /dev/null 2>&1; then
        brew install rust-analyzer > /dev/null 2>&1 || {
          echo_warning "rust-analyzer 安装失败"
          echo "  可手动安装: brew install rust-analyzer"
        }
      else
        echo_warning "rust-analyzer 不可用（非 rustup 模式）"
        echo "  macOS: brew install rust-analyzer"
        echo "  或安装 rustup 后: rustup component add rust-analyzer"
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

  local cargo_dir="${HOME}/.cargo"
  mkdir -p "${cargo_dir}"

  # cargo config（从模板链接）
  # safe_symlink 自动处理：已存在正确链接→跳过，错误链接/文件→备份重建
  safe_symlink "${RUST_DIR}/cargo_config.toml.template" "${cargo_dir}/config.toml" 2>/dev/null || true

  # rustfmt 配置（全局）
  safe_symlink "${RUST_DIR}/rustfmt.toml" "${HOME}/.rustfmt.toml" 2>/dev/null || true

  # clippy 配置（全局）
  safe_symlink "${RUST_DIR}/clippy.toml" "${HOME}/.clippy.toml" 2>/dev/null || true
}

# ======================
# 安装 cargo 扩展工具（读取 tools.list）
# ======================
install_cargo_tools() {
  if ! has_cargo; then
    echo_warning "cargo 不可用，跳过扩展工具安装"
    return 0
  fi

  echo_step "安装常用 cargo 扩展工具..."

  # 检查 tools.list 是否存在
  if ! read_tools_list > /dev/null 2>&1; then
    echo_warning "tools.list 不存在，跳过工具安装"
    return 0
  fi

  local count=0
  local failed=0

  while read -r name version; do
    [[ -z "$name" ]] && continue
    count=$((count + 1))

    if [[ -n "$version" ]]; then
      printf "${BOLD}${CYAN}${ARROW} 安装 %s@%s...${RESET}\n" "${name}" "${version}"
      if cargo install "${name}" --version "${version}" > /dev/null 2>&1; then
        echo_success "${name}@${version} 安装完成"
      else
        echo_warning "${name}@${version} 安装失败"
        failed=$((failed + 1))
      fi
    else
      printf "${BOLD}${CYAN}${ARROW} 安装 %s...${RESET}\n" "${name}"
      if cargo install "${name}" > /dev/null 2>&1; then
        echo_success "${name} 安装完成"
      else
        echo_warning "${name} 安装失败（可能需要 nightly 或网络问题）"
        failed=$((failed + 1))
      fi
    fi
  done < <(read_tools_list)

  echo ""
  if [[ $failed -eq 0 ]]; then
    echo_success "全部 ${count} 个工具安装完成"
  else
    echo_warning "${count} 个工具中 ${failed} 个安装失败"
  fi
}

# ======================
# 配置环境变量
# ======================
setup_env() {
  echo_step "配置 Rust 环境变量..."

  # 清理可能存在的无效 cargo/env 引用
  local zshrc_local="${HOME}/.zshrc.local"
  if [[ -f "${zshrc_local}" ]]; then
    if grep -q 'source.*\.cargo/env' "${zshrc_local}" 2>/dev/null; then
      local tmp_file
      tmp_file="$(mktemp)"
      grep -v 'source.*\.cargo/env' "${zshrc_local}" | grep -v '# Rust/cargo 环境' > "${tmp_file}" 2>/dev/null || true
      mv "${tmp_file}" "${zshrc_local}" 2>/dev/null || cp "${tmp_file}" "${zshrc_local}" 2>/dev/null
      rm -f "${tmp_file}"
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

    local zshenv="${HOME}/.zshenv"
    if [[ -f "${zshenv}" ]] && grep -q '.cargo/env' "${zshenv}" 2>/dev/null; then
      echo_success "环境变量已配置（.zshenv）"
      return 0
    fi

    local zshrc="${HOME}/.zshrc"
    if [[ -f "${zshrc}" ]] && grep -q '.cargo/env' "${zshrc}" 2>/dev/null; then
      echo_success "环境变量已配置（.zshrc）"
      return 0
    fi

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
  elif has_cargo; then
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

  install_rustup
  echo_separator
  install_components
  echo_separator
  link_configs
  echo_separator
  install_cargo_tools
  echo_separator
  setup_env

  echo_title "Rust 环境安装完成"
  printf "${GREEN}${CHECK} ${BOLD}Rust 开发环境配置完成！${RESET}\n"
  echo ""
  printf "${BOLD}验证:${RESET}\n"
  echo "  rustc --version"
  echo "  cargo --version"
  echo "  rustup --version"
  echo ""
  printf "${BOLD}维护命令:${RESET}\n"
  echo "  make rust-check      # 环境体检"
  echo "  make rust-upgrade    # 一键升级"
  echo "  make rust-clean      # 清理缓存"
  echo "  make rust-uninstall  # 卸载配置"
  echo ""
  echo "安装日志: ${LOG_FILE}"
  echo_separator
}

main
