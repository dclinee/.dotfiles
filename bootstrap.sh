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
# Fork 用户可用自己的仓库:
#   DOTFILES_REPO_URL=https://github.com/<user>/.dotfiles.git ./bootstrap.sh
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
#   ./bootstrap.sh --ssh      仅安装 SSH 配置
#   ./bootstrap.sh --editorconfig  仅安装 EditorConfig
#   ./bootstrap.sh --pwsh         仅安装 PowerShell 配置（跨平台）
#   ./bootstrap.sh --rollback [dir]  回滚最近/指定失败的安装
#   ./bootstrap.sh --all --dry-run   预演模式（软链/备份/删除只打印不落地）
#   DOTFILES_AUTO_ROLLBACK=false ./bootstrap.sh  禁用失败模块的自动回滚
#
# 说明:
#   --dry-run 导出 DRY_RUN=true 给所有子模块，safe_symlink/remove_symlinks/
#   clean_dirs 等文件系统操作只打印不执行；适合安装前预览将创建的软链。

set -euo pipefail

# ======================
# 变量定义
# ======================
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="${DOTFILES_DIR}"
LOG_FILE="/tmp/dotfiles_bootstrap_$(date +%Y%m%d_%H%M%S).log"
ROLLBACK_DIR="${HOME}/.cache/dotfiles_rollback_$(date +%Y%m%d_%H%M%S)"
ROLLBACK_MANIFEST="${ROLLBACK_DIR}/manifest.txt"
AUTO_ROLLBACK="${DOTFILES_AUTO_ROLLBACK:-true}"

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
INSTALL_SSH=false
INSTALL_EDITORCONFIG=false
INSTALL_PWSH=false

# ======================
# 加载共享库（fail-fast）
# ======================
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/output.sh" || { printf 'ERROR: lib/output.sh 不可用\n' >&2; exit 1; }
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/symlink.sh" || { printf 'ERROR: lib/symlink.sh 不可用\n' >&2; exit 1; }
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/common.sh" || { printf 'ERROR: lib/common.sh 不可用\n' >&2; exit 1; }

# ======================
# 自动回滚机制
# ======================

# 初始化回滚目录
_init_rollback() {
  # dry-run 下无文件改动，不创建快照目录
  if is_dry_run; then
    echo_detail "[dry-run] 跳过回滚快照初始化"
    return 0
  fi
  mkdir -p "${ROLLBACK_DIR}"
  : > "${ROLLBACK_MANIFEST}"
  echo_detail "回滚目录: ${ROLLBACK_DIR}"
}

# 记录一个文件/链接的当前状态（用于失败后恢复）
# 参数: $1 = 目标路径 (绝对路径)
_snapshot_file() {
  local target="$1"
  local safe_name
  safe_name=$(echo "$target" | sed 's|/|_|g; s|^_||')
  local snapshot="${ROLLBACK_DIR}/${safe_name}"

  # 四种状态:
  #   1. 目标不存在        → 标记 REMOVE: 安装后要删除
  #   2. 目标是符号链接     → 记录 SYMLINK: 当前链接的源
  #   3. 目标是普通文件/目录 → 完整拷贝到 snapshot
  #   4. 目标路径无法访问   → 跳过 (return 0)

  if [[ ! -e "$target" ]] && [[ ! -L "$target" ]]; then
    echo "REMOVE|${target}" >> "${ROLLBACK_MANIFEST}"
    return 0
  fi

  if [[ -L "$target" ]]; then
    local link_src
    # 先用 _resolve_link（lib/symlink.sh）把可能的相对路径 resolve 成绝对路径，
    # 否则 [[ -e ]] 会按当前目录解析，导致损坏/正常链接误判
    link_src=$(_resolve_link "$target" 2>/dev/null)
    if [[ ! -e "$link_src" ]]; then
      link_src="__broken__"
    fi
    echo "SYMLINK|${target}|${link_src}" >> "${ROLLBACK_MANIFEST}"
    return 0
  fi

  if [[ -d "$target" ]]; then
    cp -a "$target" "${snapshot}" 2>/dev/null || true
    echo "DIR|${target}|${snapshot}" >> "${ROLLBACK_MANIFEST}"
    return 0
  fi

  if [[ -f "$target" ]]; then
    cp -a "$target" "${snapshot}" 2>/dev/null || true
    echo "FILE|${target}|${snapshot}" >> "${ROLLBACK_MANIFEST}"
    return 0
  fi

  return 0
}

# 快照一批文件（方便在每个模块安装前批量记录）
# 参数: 任意多个目标路径
_snapshot_paths() {
  local p
  for p in "$@"; do
    _snapshot_file "$p"
  done
}

# 跨平台反序输出（macOS 无 tac）
_reverse_lines() {
  if command -v tac >/dev/null 2>&1; then
    tac "$1"
  elif command -v tail >/dev/null 2>&1; then
    tail -r "$1" 2>/dev/null
  else
    sed '1!G;h;$!d' "$1"
  fi
}

# 回滚一个模块的修改（根据 manifest 逆序执行）
_rollback_from_manifest() {
  local module_name="${1:-}"
  local restored=0 removed=0 failed=0

  echo_warning "执行回滚${module_name:+ (模块: ${module_name})}..."

  if [[ ! -f "${ROLLBACK_MANIFEST}" ]]; then
    echo_warning "回滚清单为空，无需操作"
    return 0
  fi

  # 从下往上处理（后装的先还原）
  while IFS='|' read -r action target snapshot; do
    # 跳过空行/未知格式
    if [[ -z "$action" ]]; then
      continue
    fi
    # 路径安全守卫：只允许操作 $HOME 下的路径
    if [[ "$target" != "$HOME"/* ]]; then
      echo_warning "跳过不安全路径: $target"
      failed=$((failed + 1))
      continue
    fi
    case "$action" in
      REMOVE)
        # 安装前不存在 → 删掉这次安装创建的链接/文件
        if [[ -L "$target" ]] || [[ -e "$target" ]]; then
          if rm -rf "$target" 2>/dev/null; then
            echo_detail "已移除: $target"
            removed=$((removed + 1))
          else
            failed=$((failed + 1))
          fi
        fi
        ;;
      SYMLINK)
        # 安装前是符号链接 → 恢复原链接
        local link_src="$snapshot"  # 第三字段是 snapshot，即原 link target
        if [[ "$link_src" == "__broken__" ]]; then
          # 安装前是损坏链接 → 直接删掉当前，重建损坏链接 (不实际)
          rm -f "$target" 2>/dev/null || true
        else
          rm -f "$target" 2>/dev/null || true
          if ln -sf "$link_src" "$target" 2>/dev/null; then
            echo_detail "已恢复链接: $target → $link_src"
            restored=$((restored + 1))
          else
            failed=$((failed + 1))
          fi
        fi
        ;;
      DIR)
        # 安装前是目录 → 还原
        if [[ -n "$snapshot" ]] && [[ -d "$snapshot" ]]; then
          rm -rf "$target" 2>/dev/null || true
          if cp -a "$snapshot" "$target" 2>/dev/null; then
            echo_detail "已恢复目录: $target"
            restored=$((restored + 1))
          else
            failed=$((failed + 1))
          fi
        fi
        ;;
      FILE)
        # 安装前是普通文件 → 还原
        if [[ -n "$snapshot" ]] && [[ -f "$snapshot" ]]; then
          if cp -a "$snapshot" "$target" 2>/dev/null; then
            echo_detail "已恢复文件: $target"
            restored=$((restored + 1))
          else
            failed=$((failed + 1))
          fi
        fi
        ;;
      *)
        : # 空行或未知，忽略
        ;;
    esac
  done < <(_reverse_lines "${ROLLBACK_MANIFEST}" 2>/dev/null)

  echo_warning "回滚完成: 恢复 ${restored} / 移除 ${removed} / 失败 ${failed}"
  [[ $failed -eq 0 ]]
}

# 每个模块执行的包装器：快照 → 安装 → 成功→丢弃快照  失败→回滚
_run_with_rollback() {
  local module_name="$1"
  shift
  local install_func="$1"
  shift

  # dry-run：安装函数内部的文件操作各自只打印，无改动则无需快照/回滚
  if is_dry_run; then
    local _dry_rc=0
    "$install_func" "$@" || _dry_rc=$?
    return "${_dry_rc}"
  fi

  # 1. 保存清单旧长度位置（模块范围标记）
  local manifest_marker="${ROLLBACK_DIR}/MANIFEST_START_$$"
  wc -l < "${ROLLBACK_MANIFEST}" > "${manifest_marker}" 2>/dev/null || true
  echo "MODULE_BEGIN|${module_name}" >> "${ROLLBACK_MANIFEST}"

  # 2. 执行模块特定的快照（由模块函数自行调用 _snapshot_paths，我们也在此快照常用 HOME 路径）
  #    注意：完整快照所有 HOME 下的 dotfiles
  case "$module_name" in
    EditorConfig)   _snapshot_paths "${HOME}/.editorconfig" ;;
    Git)            _snapshot_paths \
                      "${HOME}/.gitconfig" \
                      "${HOME}/.gitignore_global" "${HOME}/.gitattributes" ;;
    SSH)            _snapshot_paths \
                      "${HOME}/.ssh/config" "${HOME}/.ssh/config.local" ;;
    Brew)           _snapshot_paths \
                      "${HOME}/.cache/Homebrew" ;;
    Zsh)            _snapshot_paths \
                      "${HOME}/.zshrc" "${HOME}/.zshenv" \
                      "${HOME}/.config/zsh" "${HOME}/.cache/zinit" \
                      "${HOME}/.zinit" ;;
    Vim)            _snapshot_paths \
                      "${HOME}/.vimrc" "${HOME}/.vim" "${HOME}/.cache/vim" ;;
    Emacs)          _snapshot_paths \
                      "${HOME}/.emacs.d" "${HOME}/.config/emacs" \
                      "${HOME}/.emacs" "${HOME}/.emacs-custom.el" ;;
    WezTerm)        _snapshot_paths \
                      "${HOME}/.wezterm.lua" "${HOME}/.config/wezterm" ;;
    Python)         _snapshot_paths \
                      "${HOME}/.pip/pip.conf" "${HOME}/.pip" \
                      "${HOME}/.config/uv" "${HOME}/.pythonrc.py" \
                      "${HOME}/.pythonrc" \
                      "${HOME}/.cache/dotfiles-py-venv" \
                      "${HOME}/.venv-dotfiles" \
                      "${HOME}/.local/share/dotfiles-py-path" ;;
    Rust)           _snapshot_paths \
                      "${HOME}/.cargo/config.toml" "${HOME}/.cargo" \
                      "${HOME}/.rustup" \
                      "${HOME}/.config/rustfmt.toml" "${HOME}/.config/clippy.toml" ;;
    Tmux)           _snapshot_paths \
                      "${HOME}/.tmux.conf" "${HOME}/.tmux" "${HOME}/.config/tmux" ;;
  esac

  # 3. 执行安装函数
  local rc=0
  "$install_func" "$@" || rc=$?

  if [[ $rc -eq 0 ]]; then
    # 安装成功 → 仅标记模块结束（保留在 manifest 中，用户仍可全量回滚）
    echo "MODULE_OK|${module_name}" >> "${ROLLBACK_MANIFEST}"
    rm -f "${manifest_marker}"
    return 0
  else
    echo "MODULE_FAIL|${module_name}" >> "${ROLLBACK_MANIFEST}"

    if [[ "${AUTO_ROLLBACK}" == "true" ]]; then
      echo_warning "模块 ${module_name} 安装失败，自动回滚..."
      # 提取该模块的 manifest 段并做回滚
      local start_line
      start_line=$(cat "${manifest_marker}" 2>/dev/null || echo "0")
      local tmp_manifest="${ROLLBACK_DIR}/partial_$$.txt"
      # 从标记行开始到 MODULE_FAIL
      local end_line
      end_line=$(wc -l < "${ROLLBACK_MANIFEST}")
      sed -n "$((start_line + 1)),$((end_line - 1))p" "${ROLLBACK_MANIFEST}" \
        | grep -v "^MODULE_" > "${tmp_manifest}" 2>/dev/null || true
      # 用一个临时的 manifest 文件执行回滚
      local saved_manifest="${ROLLBACK_MANIFEST}"
      ROLLBACK_MANIFEST="${tmp_manifest}"
      _rollback_from_manifest "${module_name}" || true
      ROLLBACK_MANIFEST="${saved_manifest}"
      rm -f "${tmp_manifest}" "${manifest_marker}"
    fi

    return 1
  fi
}

# 完整回滚入口：用户可调用 ./bootstrap.sh --rollback <dir>
# 回滚 ROLLBACK_DIR 中最后一次失败的安装
full_rollback() {
  local rollback_dir="${1:-}"
  if [[ -z "${rollback_dir}" ]]; then
    # 找最近的一次回滚目录
    rollback_dir=$(find "${HOME}/.cache" -maxdepth 1 -type d -name 'dotfiles_rollback_*' 2>/dev/null | sort -r | head -1)
  fi
  if [[ -z "${rollback_dir}" ]] || [[ ! -d "${rollback_dir}" ]]; then
    echo_error "未找到回滚目录"
    echo "可用方式:"
    echo "  $0 --rollback <rollback_dir>"
    echo "  $0 --rollback  (自动找最近一次)"
    exit 1
  fi
  echo_title "回滚安装状态: ${rollback_dir}"
  local saved_manifest="${ROLLBACK_MANIFEST}"
  ROLLBACK_MANIFEST="${rollback_dir}/manifest.txt"
  ROLLBACK_DIR="${rollback_dir}"
  _rollback_from_manifest "ALL"
  ROLLBACK_MANIFEST="${saved_manifest}"
  echo_success "回滚执行完成，可检查回滚目录: ${rollback_dir}"
}

# 安装完成后询问是否保留快照（如果全成功可以释放空间）
_maybe_cleanup_snapshots() {
  if [[ ${#FAILED_STEPS[@]} -eq 0 ]] && [[ -d "${ROLLBACK_DIR}" ]]; then
    echo_warning "所有模块安装成功，可安全删除回滚快照: ${ROLLBACK_DIR}"
    echo "  建议保留 7 天，或手动清理: rm -rf ${ROLLBACK_DIR}"
  elif [[ -d "${ROLLBACK_DIR}" ]]; then
    echo_warning "回滚快照已保留: ${ROLLBACK_DIR}"
    echo "  如需回滚: $0 --rollback ${ROLLBACK_DIR}"
  fi
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
      --ssh)      INSTALL_SSH=true ;;
      --editorconfig) INSTALL_EDITORCONFIG=true ;;
      --pwsh) INSTALL_PWSH=true ;;
      --dry-run)
        # 导出给所有子模块 install.sh（独立 bash 进程，必须 export 才能继承）
        export DRY_RUN=true
        ;;
      --rollback)
        shift
        full_rollback "${1:-}"
        exit 0
        ;;
      -h|--help)
        head -36 "$0" | tail -31
        exit 0
        ;;
      *)
        echo_error "未知参数: $arg"
        echo "使用: $0 [--all|--zsh|--vim|--emacs|--wezterm|--brew|--python|--rust|--tmux|--git|--ssh|--editorconfig|--pwsh] [--dry-run] [--rollback [dir]]"
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

  # 支持环境变量覆盖仓库地址（方便 fork 用户使用自己的仓库）
  local repo_url="${DOTFILES_REPO_URL:-https://github.com/dclinee/.dotfiles.git}"

  echo_step "克隆 Dotfiles 仓库..."
  if git clone "${repo_url}" "${DOTFILES_DIR}" 2>>"${LOG_FILE}"; then
    echo_success "仓库克隆完成"
  else
    echo_error "仓库克隆失败，请检查网络或手动克隆"
    echo "  git clone ${repo_url} ~/.dotfiles"
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

  # 运行 zsh 安装脚本（失败必须传播退出码，交由 _run_with_rollback 记为失败并回滚）
  if ! bash "${DOTFILES_DIR}/zsh/install.sh" 2>>"${LOG_FILE}"; then
    echo_error "Zsh 安装脚本失败，请查看日志: ${LOG_FILE}"
    return 1
  fi

  # 询问是否设为默认 shell（跨平台：Linux 用 getent，macOS 用 dscl）
  _current_login_shell() {
    local shell_path=""
    if command -v getent > /dev/null 2>&1; then
      shell_path=$(getent passwd "$USER" 2>/dev/null | cut -d: -f7 2>/dev/null) || true
    else
      # macOS/BSD: 通过 dscl 读取用户记录
      shell_path=$(dscl . -read "/Users/${USER}" UserShell 2>/dev/null | awk '{print $2}') || true
    fi
    echo "$shell_path"
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

  # 创建符号链接（safe_symlink 自动处理已存在链接和备份）
  safe_symlink "${vimrc_src}" "${vimrc_dst}" || true

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
  bash "${DOTFILES_DIR}/brew/install.sh" 2>>"${LOG_FILE}"
}

# ======================
# 配置 Python 环境
# ======================
install_python() {
  bash "${DOTFILES_DIR}/python/install.sh" 2>>"${LOG_FILE}"
}

# ======================
# 配置 Rust 环境
# ======================
install_rust() {
  bash "${DOTFILES_DIR}/rust/install.sh" 2>>"${LOG_FILE}"
}

# ======================
# 安装 Tmux 配置（委托给 tmux/install.sh）
# ======================
install_tmux() {
  bash "${DOTFILES_DIR}/tmux/install.sh" 2>>"${LOG_FILE}"
}

# ======================
# 安装 Git 配置（委托给 git/install.sh）
# ======================
install_git() {
  bash "${DOTFILES_DIR}/git/install.sh" 2>>"${LOG_FILE}"
}

# ======================
# 安装 SSH 配置
# ======================
install_ssh() {
  bash "${DOTFILES_DIR}/ssh/install.sh" 2>>"${LOG_FILE}"
}

# ======================
# 创建 .editorconfig 链接
# ======================
install_editorconfig() {
  bash "${DOTFILES_DIR}/editorconfig/install.sh" 2>>"${LOG_FILE}"
}

# ======================
# 安装 PowerShell 配置（跨平台；无 pwsh 运行时时 install.sh 自行优雅跳过）
# ======================
install_pwsh() {
  bash "${DOTFILES_DIR}/pwsh/install.sh"
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

  if [[ -L "${HOME}/.gitattributes" ]]; then
    echo_success "Git: .gitattributes 已链接"
  else
    echo_warning "Git: .gitattributes 未链接（可选）"
  fi

  # 检查 Tmux
  if [[ -L "${HOME}/.tmux.conf" ]]; then
    echo_success "Tmux: .tmux.conf 已链接"
  else
    echo_error "Tmux: .tmux.conf 未链接"
    all_good=false
  fi

  # 检查 SSH
  if [[ -L "${HOME}/.ssh/config" ]]; then
    echo_success "SSH: ~/.ssh/config 已链接"
  else
    echo_warning "SSH: ~/.ssh/config 未链接（可能未安装）"
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
  if is_dry_run; then
    echo_warning "DRY-RUN 预演模式：软链创建/备份/删除只打印，不实际修改配置文件"
  fi
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

  # 初始化回滚点
  _init_rollback

  # 安装组件（每个组件独立执行，失败自动回滚模块级改动，不中断后续步骤）
  # 顺序：基础层 → 编辑器层 → 终端层 → 开发层
  # 1. EditorConfig（最早安装，所有编辑器后续加载时立即生效）
  if $INSTALL_ALL || $INSTALL_EDITORCONFIG; then
    if _run_with_rollback "EditorConfig" install_editorconfig; then
      COMPLETED_STEPS+=("EditorConfig")
    else
      FAILED_STEPS+=("EditorConfig")
    fi
  fi

  # PowerShell（Linux/macOS 未安装 pwsh 时模块自行跳过；Windows 原生请直接运行 pwsh/install.ps1）
  if $INSTALL_ALL || $INSTALL_PWSH; then
    if _run_with_rollback "PowerShell" install_pwsh; then
      COMPLETED_STEPS+=("PowerShell")
    else
      FAILED_STEPS+=("PowerShell")
    fi
  fi

  # 2. Git 配置（早期安装，影响所有后续 git 操作）
  if $INSTALL_ALL || $INSTALL_GIT; then
    if _run_with_rollback "Git" install_git; then
      COMPLETED_STEPS+=("Git")
    else
      FAILED_STEPS+=("Git")
    fi
  fi

  # 3. SSH 配置（早期安装，后续 git 远端操作可走 SSH 通道）
  if $INSTALL_ALL || $INSTALL_SSH; then
    if _run_with_rollback "SSH" install_ssh; then
      COMPLETED_STEPS+=("SSH")
    else
      FAILED_STEPS+=("SSH")
    fi
  fi

  # 4. Brew（提前安装，后续所有模块可复用）
  if $INSTALL_ALL || $INSTALL_BREW; then
    if _run_with_rollback "Brew" install_brew; then
      COMPLETED_STEPS+=("Brew")
    else
      FAILED_STEPS+=("Brew")
    fi
  fi

  # 4. Zsh（依赖 Brew 安装 zinit，内部不再执行 brew bundle）
  if $INSTALL_ALL || $INSTALL_ZSH; then
    if _run_with_rollback "Zsh" install_zsh; then
      COMPLETED_STEPS+=("Zsh")
    else
      FAILED_STEPS+=("Zsh")
    fi
  fi

  # 5. Vim（依赖 EditorConfig + 核心工具就绪）
  if $INSTALL_ALL || $INSTALL_VIM; then
    if _run_with_rollback "Vim" install_vim; then
      COMPLETED_STEPS+=("Vim")
    else
      FAILED_STEPS+=("Vim")
    fi
  fi

  # 7. Emacs（依赖 EditorConfig + 核心工具就绪）
  if $INSTALL_ALL || $INSTALL_EMACS; then
    if _run_with_rollback "Emacs" install_emacs; then
      COMPLETED_STEPS+=("Emacs")
    else
      FAILED_STEPS+=("Emacs")
    fi
  fi

  # 7. WezTerm（核心工具就绪后即可安装）
  if $INSTALL_ALL || $INSTALL_WEZTERM; then
    if _run_with_rollback "WezTerm" install_wezterm; then
      COMPLETED_STEPS+=("WezTerm")
    else
      FAILED_STEPS+=("WezTerm")
    fi
  fi

  # 8. Python（依赖 Brew 包管理器）
  if $INSTALL_ALL || $INSTALL_PYTHON; then
    if _run_with_rollback "Python" install_python; then
      COMPLETED_STEPS+=("Python")
    else
      FAILED_STEPS+=("Python")
    fi
  fi

  # 10. Rust（依赖 Brew 包管理器）
  if $INSTALL_ALL || $INSTALL_RUST; then
    if _run_with_rollback "Rust" install_rust; then
      COMPLETED_STEPS+=("Rust")
    else
      FAILED_STEPS+=("Rust")
    fi
  fi

  # 10. Tmux（依赖 Brew + Git）
  if $INSTALL_ALL || $INSTALL_TMUX; then
    if _run_with_rollback "Tmux" install_tmux; then
      COMPLETED_STEPS+=("Tmux")
    else
      FAILED_STEPS+=("Tmux")
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

  # 回滚快照处理建议
  _maybe_cleanup_snapshots
}

main "$@"
