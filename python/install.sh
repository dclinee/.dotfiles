#!/usr/bin/env bash

# ======================
# Python 开发环境安装器（部署主入口）
# ======================
#
# 功能:
#   1. 安装 uv（高性能 Python 包管理器）
#   2. 配置 uv 国内镜像源
#   3. 配置 pip 镜像源（向后兼容）
#   4. 链接 pyproject.toml（代码质量工具配置）
#   5. 链接 pythonrc.py（交互增强）
#   6. 创建虚拟环境并安装依赖
#   7. 安装 CLI 工具（读取 tools.list）
#
# 用法:
#   ./python/install.sh              # 完整安装
#   ./python/install.sh --uv-only    # 仅安装 uv
#   ./python/install.sh --dry-run    # 预览操作

set -euo pipefail

# 加载公共库与工具函数
# shellcheck source=/dev/null
source "$(dirname "$0")/_common.sh"

LOG_FILE="$(mktemp -t dotfiles_python_install_XXXXXX.log 2>/dev/null || mktemp)"

# ======================
# 参数解析
# ======================
UV_ONLY=false
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --uv-only)  UV_ONLY=true ;;
    --dry-run)  DRY_RUN=true ;;
    -h|--help)
      echo "用法: $0 [--uv-only] [--dry-run]"
      echo ""
      echo "  --uv-only   仅安装 uv，跳过依赖安装"
      echo "  --dry-run   预览操作，不实际执行"
      exit 0
      ;;
  esac
done

# ======================
# 安装 uv
#
# 优先级（遵循 PEP 668，不使用 --break-system-packages）：
#   1. 官方脚本 astral.sh（curl 下载 + sh 执行，不触碰系统 Python）  ← 推荐
#   2. pipx install uv（需 pipx 已安装）                          ← 隔离环境
#   3. 提示用户安装 pipx                                          ← 不使用 --break-system-packages
# ======================
install_uv() {
  if has_uv; then
    echo_success "uv 已安装: $(uv --version)"
    return 0
  fi

  echo_step "安装 uv..."

  # ---------- 方案 1: 官方脚本（不触碰系统 Python，推荐） ----------
  echo_detail "方案 1/3: curl -LsSf https://astral.sh/uv/install.sh | sh"
  local install_script_url="https://astral.sh/uv/install.sh"
  local tmp_script
  tmp_script="$(mktemp)"
  local _uv_tmp="${tmp_script}"
  trap "rm -f '${_uv_tmp}'" EXIT RETURN

  if is_dry_run; then
    echo_detail "[dry-run] curl -LsSf ${install_script_url} | sh"
    trap - EXIT RETURN
    rm -f "${tmp_script}"
    _register_uv_path || true
    return 0
  fi

  if curl --proto '=https' --tlsv1.2 -fsSL --connect-timeout 15 --max-time 300 "${install_script_url}" -o "${tmp_script}" 2>>"${LOG_FILE}"; then
    # 安全检查: 文件非空且以 shebang 开头
    if [[ -s "${tmp_script}" ]]; then
      local _uv_first_line
      _uv_first_line="$(head -1 "${tmp_script}")"
      if [[ "${_uv_first_line}" =~ ^#! ]]; then
        if sh "${tmp_script}" 2>>"${LOG_FILE}"; then
          trap - EXIT RETURN
          rm -f "${tmp_script}"
          if _register_uv_path; then
            echo_success "uv 安装完成（官方脚本）"
            return 0
          fi
        else
          echo_warning "官方脚本执行失败，切换方案 2"
        fi
      else
        echo_warning "下载的文件不是 shell 脚本（首行: ${_uv_first_line}），切换方案 2"
      fi
    else
      echo_warning "下载的脚本为空，切换方案 2"
    fi
  else
    echo_warning "官方脚本下载失败，切换方案 2"
  fi
  trap - EXIT RETURN
  rm -f "${tmp_script}"

  # ---------- 方案 2: pipx install uv（需 pipx 已安装） ----------
  if has_pipx; then
    echo_detail "方案 2/3: pipx install uv"
    if is_dry_run; then
      echo_detail "[dry-run] pipx install uv"
      _register_uv_path || true
      return 0
    fi

    if pipx install uv 2>>"${LOG_FILE}"; then
      if _register_uv_path; then
        echo_success "uv 安装完成（pipx 方式）"
        return 0
      fi
    else
      echo_warning "pipx 安装 uv 失败，切换方案 3"
    fi
  else
    echo_detail "方案 2/3 跳过: pipx 不可用"
  fi

  # ---------- 方案 3: 提示用户安装 pipx ----------
  echo_error "uv 安装失败（前两种方案均失败）"
  echo "  建议先安装 pipx，再重试:"
  echo "    macOS:  brew install pipx"
  echo "    通用:   python3 -m pip install --user pipx"
  echo "  安装 pipx 后执行: pipx install uv"
  echo "  或使用官方脚本: curl -LsSf https://astral.sh/uv/install.sh | sh"
  return 1
}

# 辅助: 确保 ~/.local/bin 在 PATH 中，并 has_uv 可识别
_register_uv_path() {
  local uv_bin="${HOME}/.local/bin"
  if [[ -f "${uv_bin}/uv" ]]; then
    export PATH="${uv_bin}:${PATH}"
    return 0
  fi
  return 1
}

# ======================
# 配置 uv 镜像源
# ======================
configure_uv_mirror() {
  [[ -n "${NO_MIRROR:-}" ]] && { echo_skip "NO_MIRROR 已设置，跳过镜像配置"; return 0; }
  echo_step "配置 uv 镜像源..."

  local uv_config_dir="${HOME}/.config/uv"
  mkdir -p "${uv_config_dir}"

  if $DRY_RUN; then
    echo_detail "[dry-run] 将链接 ${PYTHON_DIR}/uv.toml.template → ${uv_config_dir}/uv.toml"
    return 0
  fi

  safe_symlink "${PYTHON_DIR}/uv.toml.template" "${uv_config_dir}/uv.toml" || true
  echo_success "uv 配置已链接"
}

# ======================
# 配置 pip 镜像源（向后兼容）
# ======================
configure_pip_mirror() {
  [[ -n "${NO_MIRROR:-}" ]] && { echo_skip "NO_MIRROR 已设置，跳过镜像配置"; return 0; }
  echo_step "配置 pip 镜像源..."

  local pip_config_dir="${HOME}/.pip"
  mkdir -p "${pip_config_dir}"

  if $DRY_RUN; then
    echo_detail "[dry-run] 将链接 ${PYTHON_DIR}/pip.conf → ${pip_config_dir}/pip.conf"
    return 0
  fi

  safe_symlink "${PYTHON_DIR}/pip.conf" "${pip_config_dir}/pip.conf" || true
  echo_success "pip 配置已链接"
}

# ======================
# 链接 pythonrc.py
# ======================
link_pythonrc() {
  echo_step "链接 Python 交互配置..."

  if $DRY_RUN; then
    echo_detail "[dry-run] 将链接 ${PYTHON_DIR}/pythonrc.py → ${HOME}/.pythonrc.py"
    return 0
  fi

  safe_symlink "${PYTHON_DIR}/pythonrc.py" "${HOME}/.pythonrc.py" || true
  echo_success "pythonrc.py 已链接"
}

# ======================
# 链接 pyproject.toml（代码质量工具配置）
# ======================
link_pyproject() {
  echo_step "链接 pyproject.toml..."

  # 说明: black/ruff/mypy 在项目根目录查找 pyproject.toml
  # 此处链接到 ~/.pyproject.toml 作为全局默认配置
  # 新项目可从此模板复制到项目根目录
  local pyproject_link="${HOME}/.pyproject.toml"

  if $DRY_RUN; then
    echo_detail "[dry-run] 将链接 ${PYTHON_DIR}/pyproject.toml.template → ${pyproject_link}"
    return 0
  fi

  safe_symlink "${PYTHON_DIR}/pyproject.toml.template" "${pyproject_link}" || true
  echo_success "pyproject.toml 已链接（全局默认）"
}

# ======================
# 安装 Python 依赖（使用 uv）
# ======================
install_python_deps() {
  echo_step "安装 Python 依赖..."

  local req_file="${PYTHON_DIR}/requirements.txt"
  if [[ ! -f "$req_file" ]]; then
    echo_warning "未找到 requirements.txt，跳过依赖安装"
    return 0
  fi

  if $DRY_RUN; then
    echo_detail "[dry-run] 将使用 uv 创建虚拟环境并安装依赖"
    echo_detail "  uv venv ~/.venv-dotfiles"
    echo_detail "  uv pip install -r ${req_file}"
    return 0
  fi

  # 使用 uv 创建虚拟环境
  local venv_dir="${HOME}/.venv-dotfiles"
  if has_uv; then
    echo_step "使用 uv 创建虚拟环境: ${venv_dir}"

    # 策略链: 已存在检查 → --clear 替换 → 普通创建 → --force 清理损坏 → python3 -m venv
    local venv_created=false

    if [[ -f "${venv_dir}/pyvenv.cfg" ]]; then
      echo_detail "虚拟环境已存在且有效，跳过创建"
      venv_created=true
    elif uv venv --clear "${venv_dir}" 2>>"${LOG_FILE}"; then
      echo_warning "旧 venv 已存在，使用 --clear 重建"
      venv_created=true
    elif uv venv "${venv_dir}" 2>>"${LOG_FILE}"; then
      venv_created=true
    elif uv venv --force "${venv_dir}" 2>>"${LOG_FILE}"; then
      echo_warning "检测到损坏的旧 venv，已使用 --force 清理重建"
      venv_created=true
    elif python3 -m venv "${venv_dir}" 2>>"${LOG_FILE}"; then
      echo_warning "uv 创建失败，回退到 python3 -m venv"
      venv_created=true
    fi

    if ! $venv_created; then
      echo_error "虚拟环境创建失败，请查看日志: ${LOG_FILE}"
      return 1
    fi

    echo_step "使用 uv 安装依赖..."
    if uv pip install --python "${venv_dir}/bin/python" -r "${req_file}" 2>>"${LOG_FILE}"; then
      echo_success "Python 依赖安装完成"
    else
      echo_error "依赖安装失败，请查看日志: ${LOG_FILE}"
      return 1
    fi

    # 写入 PATH 标记文件
    local marker="${HOME}/.local/share/dotfiles-py-path"
    mkdir -p "$(dirname "${marker}")"
    printf '%s\n' "${venv_dir}/bin" > "${marker}"
    echo_detail "已写入 PATH 标记: ${marker}"
  else
    echo_warning "uv 未安装，回退到 pip 安装"
    local externally_managed=false
    if pip3 install --dry-run "pip" 2>&1 | grep -qi "externally-managed"; then
      externally_managed=true
    fi

    if $externally_managed; then
      echo_warning "检测到 PEP 668 外部管理环境，跳过 --user 方案"
      echo "  建议: 安装 uv 后重试，或手动创建虚拟环境"
      return 0
    fi

    pip3 install --user -r "${req_file}" 2>>"${LOG_FILE}" || {
      echo_error "pip 安装失败，请查看日志: ${LOG_FILE}"
      return 1
    }
    echo_success "Python 依赖安装完成（pip 模式）"
  fi
}

# ======================
# 安装 CLI 工具（读取 tools.list）
# ======================
install_cli_tools() {
  if ! has_uv && ! has_pipx; then
    echo_warning "uv 和 pipx 均不可用，跳过 CLI 工具安装"
    return 0
  fi

  if ! read_tools_list > /dev/null 2>&1; then
    echo_warning "tools.list 不存在，跳过 CLI 工具安装"
    return 0
  fi

  echo_step "安装 CLI 工具..."

  local count=0
  local installed=0
  local skipped=0

  while read -r name version; do
    [[ -z "$name" ]] && continue
    count=$((count + 1))

    # 检查是否已安装
    if command -v "$name" > /dev/null 2>&1; then
      echo_skip "已安装: ${name}"
      skipped=$((skipped + 1))
      continue
    fi

    printf "${BOLD}${CYAN}${ARROW} 安装 %s...${RESET}\n" "${name}"

    if $DRY_RUN; then
      echo_detail "[dry-run] uv tool install ${name}"
      continue
    fi

    if has_uv; then
      if [[ -n "$version" ]]; then
        if uv tool install "$name" --version "$version" > /dev/null 2>&1; then
          echo_success "${name}@${version} 已安装"
          installed=$((installed + 1))
        else
          echo_warning "${name}@${version} 安装失败"
        fi
      else
        if uv tool install "$name" > /dev/null 2>&1; then
          echo_success "${name} 已安装"
          installed=$((installed + 1))
        else
          echo_warning "${name} 安装失败"
        fi
      fi
    elif has_pipx; then
      if pipx install "$name" > /dev/null 2>&1; then
        echo_success "${name} 已安装（pipx）"
        installed=$((installed + 1))
      else
        echo_warning "${name} 安装失败（pipx）"
      fi
    fi
  done < <(read_tools_list)

  if ! $DRY_RUN; then
    echo ""
    echo_success "CLI 工具安装: ${installed} 新装 / ${skipped} 已存在 / ${count} 总计"
  fi
}

# ======================
# 提示可选依赖
# ======================
show_optional_hint() {
  local optional_files=("requirements-dev.txt" "requirements-data.txt" "requirements-web.txt")
  local opt_file
  for opt_file in "${optional_files[@]}"; do
    if [[ -f "${PYTHON_DIR}/${opt_file}" ]]; then
      echo_step "可选依赖（不自动安装）: ${opt_file}"
      echo "  按需安装: uv pip install -r python/${opt_file}"
      break
    fi
  done
}

# ======================
# 主流程
# ======================
main() {
  echo_title "Python 环境安装器"

  install_uv || return 1
  configure_uv_mirror || true

  if $UV_ONLY; then
    echo_success "uv 安装完成（--uv-only 模式）"
    return 0
  fi

  configure_pip_mirror || true
  link_pythonrc || true
  link_pyproject || true
  install_python_deps || return 1
  install_cli_tools || true
  show_optional_hint

  echo_title "安装完成"
  echo_success "Python 环境配置完成"
  echo_detail "uv 版本: $(uv --version 2>/dev/null || echo '未安装')"
  echo_detail "虚拟环境: ${HOME}/.venv-dotfiles"
  echo_detail "激活命令: source ${HOME}/.venv-dotfiles/bin/activate"
}

main "$@"
