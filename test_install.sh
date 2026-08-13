#!/usr/bin/env bash
# ======================
# Dotfiles 安装脚本测试器
# 模拟 macOS 和 Linux 环境，验证所有修复效果
# ======================

set -eo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_DIR=""
# 保存原始 PATH，避免后续测试环境的 mock 命令污染 command -v 查找
ORIGINAL_PATH="${PATH:-}"
PASS=0
FAIL=0
TOTAL=0
FAILED_TESTS=()

# 颜色定义
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[36m'
RESET='\033[0m'
BOLD='\033[1m'

# ======================
# 测试框架
# ======================

log_info()  { printf "${BLUE}[INFO]${RESET} %s\n" "$*"; }
log_ok()    { printf "${GREEN}[OK]${RESET} %s\n" "$*"; }
log_warn()  { printf "${YELLOW}[WARN]${RESET} %s\n" "$*"; }
log_err()   { printf "${RED}[FAIL]${RESET} %s\n" "$*"; }

assert_pass() {
  PASS=$((PASS + 1))
  TOTAL=$((TOTAL + 1))
  log_ok "$*"
}

assert_fail() {
  FAIL=$((FAIL + 1))
  TOTAL=$((TOTAL + 1))
  FAILED_TESTS+=("$*")
  log_err "$*"
}

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    assert_pass "$name"
  else
    assert_fail "$name (expected: '$expected', got: '$actual')"
  fi
}

assert_contains() {
  local name="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    assert_pass "$name"
  else
    assert_fail "$name (missing: '$needle')"
  fi
}

assert_file_contains() {
  local name="$1" path="$2" pattern="$3"
  if grep -q -- "$pattern" "$path" 2>/dev/null; then
    assert_pass "$name"
  else
    assert_fail "$name (pattern '$pattern' not found in $path)"
  fi
}

assert_file_contains_ere() {
  local name="$1" path="$2" pattern="$3"
  if grep -qE -- "$pattern" "$path" 2>/dev/null; then
    assert_pass "$name"
  else
    assert_fail "$name (ERE pattern '$pattern' not found in $path)"
  fi
}

assert_file_not_contains() {
  local name="$1" path="$2" pattern="$3"
  if ! grep -q -- "$pattern" "$path" 2>/dev/null; then
    assert_pass "$name"
  else
    assert_fail "$name (pattern '$pattern' should not exist in $path)"
  fi
}

assert_file_not_contains_ere() {
  local name="$1" path="$2" pattern="$3"
  if ! grep -qE -- "$pattern" "$path" 2>/dev/null; then
    assert_pass "$name"
  else
    assert_fail "$name (ERE pattern '$pattern' should not exist in $path)"
  fi
}

assert_file_exists() {
  local name="$1" path="$2"
  if [[ -e "$path" ]]; then
    assert_pass "$name"
  else
    assert_fail "$name (file not found: $path)"
  fi
}

# ======================
# 环境准备
# ======================

setup_test_env() {
  local ostype="$1"
  local arch="$2"

  TEST_DIR=$(mktemp -d)
  trap "cleanup_test_env" EXIT

  log_info "创建测试环境: $TEST_DIR"

  # 创建 mock 目录结构
  mkdir -p "$TEST_DIR/bin"
  mkdir -p "$TEST_DIR/home/.cache/zsh"
  mkdir -p "$TEST_DIR/home/.dotfiles"
  mkdir -p "$TEST_DIR/home/.local/bin"
  mkdir -p "$TEST_DIR/home/.local/lib"
  mkdir -p "$TEST_DIR/home/.virtualenvs"
  mkdir -p "$TEST_DIR/home/.pip"

  # 复制 dotfiles 到测试环境
  cp -r "$DOTFILES_DIR/zsh" "$TEST_DIR/home/.dotfiles/"
  cp -r "$DOTFILES_DIR/brew" "$TEST_DIR/home/.dotfiles/"
  cp -r "$DOTFILES_DIR/python" "$TEST_DIR/home/.dotfiles/" 2>/dev/null || true
  cp -r "$DOTFILES_DIR/wezterm" "$TEST_DIR/home/.dotfiles/" 2>/dev/null || true
  cp -r "$DOTFILES_DIR/lib" "$TEST_DIR/home/.dotfiles/" 2>/dev/null || true

  # 创建 mock 命令
  create_mock_commands "$ostype" "$arch"

  # 设置 mock 环境变量
  export HOME="$TEST_DIR/home"
  export PATH="$TEST_DIR/bin:$PATH"
  export __TEST_OSTYPE="$ostype"
  export __TEST_ARCH="$arch"
  export __TEST_MODE="1"

  log_info "模拟环境: OSTYPE=$ostype, ARCH=$arch"
}

create_mock_commands() {
  local ostype="$1"
  local arch="$2"

  # === uname mock ===
  cat > "$TEST_DIR/bin/uname" << 'MOCK_EOF'
#!/usr/bin/env bash
case "$1" in
  -s) echo "${__TEST_OSTYPE:-Linux}" ;;
  -m) echo "${__TEST_ARCH:-x86_64}" ;;
  -a) echo "${__TEST_OSTYPE:-Linux} test-host 5.15.0 zsh #1 SMP x86_64 GNU/Linux" ;;
  *)  echo "${__TEST_OSTYPE:-Linux}" ;;
esac
MOCK_EOF
  chmod +x "$TEST_DIR/bin/uname"

  # === brew mock ===
  cat > "$TEST_DIR/bin/brew" << 'MOCK_EOF'
#!/usr/bin/env bash
case "$1" in
  shellenv)
    cat << 'INNEREOF'
export HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
export HOMEBREW_CELLAR="/home/linuxbrew/.linuxbrew/Cellar"
export HOMEBREW_REPOSITORY="/home/linuxbrew/.linuxbrew/Homebrew"
export PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"
export HOMEBREW_NO_AUTO_UPDATE="1"
export HOMEBREW_NO_ANALYTICS="1"
INNEREOF
    ;;
  install|list|info|doctor|update)
    echo "[MOCK] brew $* executed" >&2
    ;;
  *)
    echo "[MOCK] brew $* - success" >&2
    exit 0
    ;;
esac
MOCK_EOF
  chmod +x "$TEST_DIR/bin/brew"

  # === git mock ===
  cat > "$TEST_DIR/bin/git" << 'MOCK_EOF'
#!/usr/bin/env bash
if [[ "$1" == "clone" ]]; then
  repo="" dest=""
  for arg in "$@"; do
    if [[ "$arg" =~ ^https?:// ]]; then
      repo="$arg"
    elif [[ "$arg" =~ ^- ]]; then
      continue
    elif [[ -d "$arg" ]]; then
      dest="$arg"
    fi
  done
  if [[ -n "$dest" ]]; then
    mkdir -p "$dest/.git"
    echo "[MOCK] git clone $repo -> $dest" >&2
    exit 0
  fi
fi
echo "[MOCK] git $*" >&2
MOCK_EOF
  chmod +x "$TEST_DIR/bin/git"

  # === zsh mock (for install.sh execution) ===
  cat > "$TEST_DIR/bin/zsh" << 'MOCK_EOF'
#!/usr/bin/env bash
echo "[MOCK] zsh $*" >&2
if [[ "$1" == "-n" ]]; then
  exit 0
fi
MOCK_EOF
  chmod +x "$TEST_DIR/bin/zsh"

  # === bash mock (用于 curl|sh 管道) ===
  cat > "$TEST_DIR/bin/sh" << 'MOCK_EOF'
#!/usr/bin/env bash
echo "[MOCK] sh $*" >&2
exit 0
MOCK_EOF
  chmod +x "$TEST_DIR/bin/sh"

  # === curl mock ===
  cat > "$TEST_DIR/bin/curl" << 'MOCK_EOF'
#!/usr/bin/env bash
echo "[MOCK] curl $*" >&2
# 对 install.sh 中 starship 安装的 curl|sh 返回成功
exit 0
MOCK_EOF
  chmod +x "$TEST_DIR/bin/curl"

  # === zoxide mock ===
  cat > "$TEST_DIR/bin/zoxide" << 'MOCK_EOF'
#!/usr/bin/env bash
if [[ "$1" == "init" && "$2" == "zsh" ]]; then
  echo '# Mock zoxide init for zsh'
  echo 'export _ZO_DATA_DIR="/tmp"'
  echo 'zoxide() { echo "[MOCK] zoxide $*"; }'
else
  echo "[MOCK] zoxide $*" >&2
fi
MOCK_EOF
  chmod +x "$TEST_DIR/bin/zoxide"

  # === starship mock ===
  cat > "$TEST_DIR/bin/starship" << 'MOCK_EOF'
#!/usr/bin/env bash
if [[ "$1" == "init" && "$2" == "zsh" ]]; then
  echo '# Mock starship init zsh'
else
  echo "[MOCK] starship $*" >&2
fi
MOCK_EOF
  chmod +x "$TEST_DIR/bin/starship"

  # === 其他通用 mock ===
  # 文件操作 + 文本处理命令透传真实命令（用绝对路径避免递归调用 mock 自身）
  # 关键：用 ORIGINAL_PATH 查找真实命令，避免上一次测试的 mock bin 污染查找结果
  local real_cmd
  for cmd in mkdir ln rm cat cp mv touch chmod chown grep sed awk find wc; do
    real_cmd=$(PATH="$ORIGINAL_PATH" command -v "$cmd" 2>/dev/null || echo "/bin/$cmd")
    cat > "$TEST_DIR/bin/$cmd" << MOCK_EOF
#!/usr/bin/env bash
exec "$real_cmd" "\$@"
MOCK_EOF
    chmod +x "$TEST_DIR/bin/$cmd"
  done

  # 其余命令纯 mock（不影响文件系统）
  for cmd in eza date stat python3 pip3 apt dnf pacman free lscpu top ip ifconfig vm_stat sysctl; do
    cat > "$TEST_DIR/bin/$cmd" << MOCK_EOF
#!/usr/bin/env bash
echo "[MOCK] $cmd \$*" >&2
exit 0
MOCK_EOF
    chmod +x "$TEST_DIR/bin/$cmd"
  done

  # sudo mock - 透传
  cat > "$TEST_DIR/bin/sudo" << 'MOCK_EOF'
#!/usr/bin/env bash
"$@"
MOCK_EOF
  chmod +x "$TEST_DIR/bin/sudo"

  # fc-list mock
  cat > "$TEST_DIR/bin/fc-list" << 'MOCK_EOF'
#!/usr/bin/env bash
if [[ "$*" =~ ": family" ]]; then
  echo "DejaVu Sans"
  echo "FiraCode Nerd Font"
  echo "Noto Sans Mono"
fi
MOCK_EOF
  chmod +x "$TEST_DIR/bin/fc-list"
}

cleanup_test_env() {
  if [[ -n "$TEST_DIR" ]] && [[ -d "$TEST_DIR" ]]; then
    # 用 ORIGINAL_PATH 查找真实 rm，避免调用刚被删除的 mock rm
    local real_rm
    real_rm=$(PATH="$ORIGINAL_PATH" command -v rm 2>/dev/null || echo "/bin/rm")
    "$real_rm" -rf "$TEST_DIR"
  fi
  # 恢复 PATH，避免污染后续测试
  export PATH="$ORIGINAL_PATH"
}

# ======================
# 测试用例
# ======================

test_install_sh_syntax() {
  log_info "测试: install.sh 语法"
  if bash -n "$DOTFILES_DIR/zsh/install.sh" 2>/dev/null; then
    assert_pass "install.sh bash 语法检查通过"
  else
    assert_fail "install.sh bash 语法检查失败"
  fi
}

test_zoxide_redirect_fix() {
  log_info "测试: zoxide 重定向修复 (P0)"
  local content
  content=$(cat "$DOTFILES_DIR/zsh/install.sh")

  assert_contains "zoxide init 存在" "$content" "zoxide init zsh"
  assert_file_not_contains "zoxide 无双 > 重定向" "$DOTFILES_DIR/zsh/install.sh" "zoxide init zsh.*>.*> /dev/null"
  assert_file_contains "zoxide init 输出到 init.zsh" "$DOTFILES_DIR/zsh/install.sh" "init.zsh"
  assert_file_contains "zoxide init stderr 到日志" "$DOTFILES_DIR/zsh/install.sh" "LOG_FILE"
}

test_zinit_removal() {
  log_info "测试: zinit 已正确集成"
  local zsh_dir="$DOTFILES_DIR/zsh"

  # 项目已迁移到 zinit 插件管理器，验证其正确引用
  assert_file_contains "install.sh 包含 zinit 安装" \
    "$zsh_dir/install.sh" "zinit"

  assert_file_contains "04_plugins.zsh 使用 zinit" \
    "$zsh_dir/core/04_plugins.zsh" "zinit"

  assert_file_not_contains "zshrc 不直接 source zinit（由 04_plugins 处理）" \
    "$zsh_dir/.zshrc" "source.*zinit.zsh"
}

test_brewfile_fix() {
  log_info "测试: Brewfile 语法修复"

  assert_file_not_contains "Brewfile.linux 无 eval cat" \
    "$DOTFILES_DIR/brew/Brewfile.linux" "eval.*cat"

  assert_file_not_contains "Brewfile.macos 无 eval cat" \
    "$DOTFILES_DIR/brew/Brewfile.macos" "eval.*cat"

  # brew bundle 不支持嵌套引用（brewfile 指令不存在），
  # 平台 Brewfile 仅包含平台特定包，通用包在主 Brewfile 中
  assert_file_not_contains "Brewfile.linux 无 brewfile 指令" \
    "$DOTFILES_DIR/brew/Brewfile.linux" "brewfile"

  assert_file_not_contains "Brewfile.macos 无 brewfile 指令" \
    "$DOTFILES_DIR/brew/Brewfile.macos" "brewfile"

  assert_file_not_contains "Brewfile.linux 无 cask 指令" \
    "$DOTFILES_DIR/brew/Brewfile.linux" "^cask"

  assert_file_not_contains "主 Brewfile 无 cask 指令" \
    "$DOTFILES_DIR/brew/Brewfile" "^cask"
}

test_env_zsh_fixes() {
  log_info "测试: 00_env.zsh 修复"
  local env_file="$DOTFILES_DIR/zsh/core/00_env.zsh"

  # PYTHONPATH 已移除（避免污染其他 Python 项目）
  assert_file_not_contains "PYTHONPATH 不再污染全局" \
    "$env_file" 'export PYTHONPATH'

  assert_file_contains "PYTHONPATH 移除有注释说明" \
    "$env_file" "已移除对 PYTHONPATH"

  # HISTORY_IGNORE（正确的 Zsh 变量名）
  assert_file_contains "HISTORY_IGNORE 正确变量名" \
    "$env_file" "HISTORY_IGNORE="

  # 无无效的 HISTORY_IGNORE_ALL（不是有效 Zsh 变量）
  if grep -q 'HISTORY_IGNORE_ALL' "$env_file" 2>/dev/null; then
    assert_fail "存在无效 HISTORY_IGNORE_ALL 变量"
  else
    assert_pass "无无效 HISTORY_IGNORE_ALL 变量"
  fi

  # 检查 Linux brew 路径检查：统计 export PATH 中包含 linuxbrew 的行数
  local linuxbrew_count
  linuxbrew_count=$(grep -c 'export PATH.*linuxbrew/bin' "$env_file" 2>/dev/null || true)
  linuxbrew_count=${linuxbrew_count:-0}
  if [[ "$linuxbrew_count" -le 2 ]]; then
    assert_pass "Linux brew 路径检查无重复条件 (${linuxbrew_count} 处 export PATH)"
  else
    assert_fail "Linux brew 路径检查有重复条件 (${linuxbrew_count} 处)"
  fi
}

test_plugins_fix() {
  log_info "测试: 04_plugins.zsh zinit 架构"
  local plugins_file="$DOTFILES_DIR/zsh/core/04_plugins.zsh"

  # 项目已迁移到 zinit 插件管理器
  assert_file_contains "使用 zinit 插件管理器" "$plugins_file" "zinit"

  assert_file_contains "支持 ZSH_DISABLE_PLUGINS" "$plugins_file" "ZSH_DISABLE_PLUGINS"

  # zinit 架构下的辅助函数
  assert_file_contains "包含 list_plugins 函数" "$plugins_file" "list_plugins"

  assert_file_contains "包含 update_plugins 函数" "$plugins_file" "update_plugins"

  # 调试支持
  assert_file_contains "支持 ZSH_DEBUG_PLUGINS" "$plugins_file" "ZSH_DEBUG_PLUGINS"

  # zsh 语法检查
  if command -v zsh > /dev/null 2>&1; then
    if zsh -n "$plugins_file" 2>/dev/null; then
      assert_pass "04_plugins.zsh zsh 语法检查通过"
    else
      assert_fail "04_plugins.zsh zsh 语法检查失败"
    fi
  fi
}

test_starship_font_detection() {
  log_info "测试: starship Nerd Font 检测与降级"
  local starship_file="$DOTFILES_DIR/zsh/core/05_starship.zsh"

  assert_file_contains "包含 _has_nerd_font 函数" "$starship_file" "_has_nerd_font"
  assert_file_contains "包含 fc-list 检测" "$starship_file" "fc-list"
  assert_file_contains "包含字体目录扫描" "$starship_file" ".local/share/fonts"
  assert_file_contains "包含 brew 字体检测" "$starship_file" "share/fonts"
  assert_file_contains "引用 starship_fallback.toml" "$starship_file" "starship_fallback.toml"

  if command -v zsh > /dev/null 2>&1; then
    if zsh -n "$starship_file" 2>/dev/null; then
      assert_pass "05_starship.zsh zsh 语法检查通过"
    else
      assert_fail "05_starship.zsh zsh 语法检查失败"
    fi
  fi
}

test_zshenv_entry() {
  log_info "测试: .zshenv 入口文件"
  local zshenv_file="$DOTFILES_DIR/zsh/.zshenv"

  assert_file_exists ".zshenv 文件存在" "$zshenv_file"
  assert_file_contains ".zshenv 设置 ZSH_HOME" "$zshenv_file" "ZSH_HOME"
  assert_file_contains ".zshenv 设置 Homebrew PATH" "$zshenv_file" "linuxbrew"
  assert_file_contains ".zshenv 设置 macOS brew 路径" "$zshenv_file" "opt/homebrew"
  assert_file_contains ".zshenv 设置 x86 brew 路径" "$zshenv_file" "/usr/local"
  assert_file_contains ".zshenv 有交互式检查" "$zshenv_file" "interactive"

  assert_file_contains "install.sh 创建 .zshenv 链接" \
    "$DOTFILES_DIR/zsh/install.sh" ".zshenv"
}

test_cross_platform_compat() {
  log_info "测试: 跨平台兼容性"

  local func_file="$DOTFILES_DIR/zsh/core/03_functions.zsh"
  assert_file_contains "03_functions 有 lscpu 条件判断" "$func_file" "command -v lscpu"
  assert_file_contains "03_functions 有 sysctl 降级" "$func_file" "command -v sysctl"
  assert_file_contains "03_functions 有 free 条件判断" "$func_file" "command -v free"
  assert_file_contains "03_functions 有 vm_stat 降级" "$func_file" "command -v vm_stat"
  assert_file_contains "03_functions 有 ip 条件判断" "$func_file" "command -v ip"
  assert_file_contains "03_functions 有 ifconfig 降级" "$func_file" "command -v ifconfig"

  local opt_file="$DOTFILES_DIR/zsh/core/01_options.zsh"
  assert_file_contains "01_options 有 ZSH_COMPDUMP 缓存" "$opt_file" "ZSH_COMPDUMP"
  assert_file_contains "01_options 有 compinit -C 快速路径" "$opt_file" "compinit -C"
  assert_file_contains "01_options 有 compinit -u 重建路径" "$opt_file" "compinit -u"
  assert_file_contains "01_options 有 LS_COLORS 非空检查" "$opt_file" 'LS_COLORS'
}

test_install_error_handling() {
  log_info "测试: install.sh 错误处理"

  assert_file_contains "starship 安装使用安全下载" \
    "$DOTFILES_DIR/zsh/install.sh" "_download_and_run.*starship"

  assert_file_contains "brew install 有 if 判断" \
    "$DOTFILES_DIR/zsh/install.sh" "if brew install"

  assert_file_contains "apt install 有 if 判断" \
    "$DOTFILES_DIR/zsh/install.sh" "if sudo apt install"

  # brew shellenv 和 pip 安装逻辑已移至 bootstrap.sh
  assert_file_contains "bootstrap.sh brew bundle 有 || 保护" \
    "$DOTFILES_DIR/bootstrap.sh" "brew bundle.*||"
}

test_install_brew_fixes() {
  log_info "测试: brew/install.sh 修复"
  local brew_install="$DOTFILES_DIR/brew/install.sh"

  assert_file_contains "install.sh 有 set -euo pipefail" "$brew_install" "set -euo pipefail"
  assert_file_contains "install.sh 有 brew shellenv 条件判断" "$brew_install" "command -v brew"
  assert_file_contains "install.sh 有 Linux 条件" "$brew_install" "Linux"
  assert_file_contains "install.sh 有 Darwin 条件" "$brew_install" "Darwin"
  assert_file_not_contains "install.sh 无无效 cask 镜像" "$brew_install" "HOMEBREW_CASK"
  assert_file_contains "install.sh 有持久化提示" "$brew_install" "brew shellenv"
}

test_fallback_config_generation() {
  log_info "测试: 降级配置生成"
  local starship_file="$DOTFILES_DIR/zsh/starship/starship_fallback.toml"

  # 检查降级配置中的 Unicode 符号（在独立 TOML 文件中）
  assert_file_contains "降级配置使用 Unicode 三角" "$starship_file" "▓"
  assert_file_contains "降级配置使用 Unicode 角标" "$starship_file" "░"

  # 检查降级配置中的 symbol 定义
  assert_file_contains "降级配置 c 使用 ◆" "$starship_file" 'symbol.*◆'
  assert_file_contains "降级配置 cpp 使用 ◇" "$starship_file" 'symbol.*◇'
  assert_file_contains "降级配置 rust 使用 ⚙" "$starship_file" 'symbol.*⚙'
  assert_file_contains "降级配置 golang 使用 ▲" "$starship_file" 'symbol.*▲'
  assert_file_contains "降级配置 python 使用 🐍" "$starship_file" 'symbol.*🐍'
}

test_starship_toml_comments() {
  log_info "测试: starship.toml Nerd Font 说明"
  local toml_file="$DOTFILES_DIR/zsh/starship/starship.toml"

  assert_file_contains "starship.toml 有 Nerd Font 说明" "$toml_file" "Nerd Font"
  assert_file_contains "starship.toml 有降级说明" "$toml_file" "降级"
}

test_all_zsh_syntax() {
  log_info "测试: 所有 zsh 配置文件语法"

  if ! command -v zsh > /dev/null 2>&1; then
    log_warn "zsh 不可用，跳过语法检查"
    return
  fi

  local zsh_files=(
    "$DOTFILES_DIR/zsh/.zshrc"
    "$DOTFILES_DIR/zsh/.zshenv"
    "$DOTFILES_DIR/zsh/core/00_env.zsh"
    "$DOTFILES_DIR/zsh/core/01_options.zsh"
    "$DOTFILES_DIR/zsh/core/02_aliases.zsh"
    "$DOTFILES_DIR/zsh/core/03_functions.zsh"
    "$DOTFILES_DIR/zsh/core/04_plugins.zsh"
    "$DOTFILES_DIR/zsh/core/05_starship.zsh"
    "$DOTFILES_DIR/zsh/platform/linux.zsh"
    "$DOTFILES_DIR/zsh/platform/macos.zsh"
  )

  for file in "${zsh_files[@]}"; do
    if [[ -f "$file" ]]; then
      local basename
      basename=$(basename "$file")
      if zsh -n "$file" 2>/dev/null; then
        assert_pass "zsh 语法: $basename"
      else
        assert_fail "zsh 语法: $basename"
      fi
    fi
  done
}

test_all_bash_syntax() {
  log_info "测试: 所有 bash 脚本语法"

  local bash_files=(
    "$DOTFILES_DIR/bootstrap.sh"
    "$DOTFILES_DIR/zsh/install.sh"
    "$DOTFILES_DIR/brew/install.sh"
    "$DOTFILES_DIR/wezterm/install.sh"
    "$DOTFILES_DIR/vim/install.sh"
    "$DOTFILES_DIR/rust/install.sh"
    "$DOTFILES_DIR/rust/uninstall.sh"
    "$DOTFILES_DIR/rust/check.sh"
    "$DOTFILES_DIR/rust/upgrade.sh"
    "$DOTFILES_DIR/rust/clean.sh"
    "$DOTFILES_DIR/rust/pin.sh"
    "$DOTFILES_DIR/rust/_common.sh"
    "$DOTFILES_DIR/validate.sh"
  )

  for file in "${bash_files[@]}"; do
    if [[ -f "$file" ]]; then
      local basename
      basename=$(basename "$file")
      if bash -n "$file" 2>/dev/null; then
        assert_pass "bash 语法: $basename"
      else
        assert_fail "bash 语法: $basename"
      fi
    fi
  done
}

test_platform_files() {
  log_info "测试: 平台文件跨平台检查"

  assert_file_not_contains "macos.zsh 无 free 命令" \
    "$DOTFILES_DIR/zsh/platform/macos.zsh" "free"

  assert_file_not_contains "linux.zsh 无 defaults 命令" \
    "$DOTFILES_DIR/zsh/platform/linux.zsh" "defaults"
}

test_performance_script() {
  log_info "测试: profile_performance.sh"
  local perf_file="$DOTFILES_DIR/zsh/profile_performance.sh"

  assert_file_exists "profile_performance.sh 存在" "$perf_file"
  assert_file_contains "包含 zprof 检测" "$perf_file" "zprof"
  assert_file_contains "包含 ZSH_DISABLE_PLUGINS 提示" "$perf_file" "ZSH_DISABLE_PLUGINS"
  assert_file_contains "包含 list_plugins 调用" "$perf_file" "list_plugins"
  assert_file_contains "包含 ZSH_DEBUG_PLUGINS 提示" "$perf_file" "ZSH_DEBUG_PLUGINS"
}

test_plugin_order() {
  log_info "测试: zinit 插件加载顺序"
  local plugins_file="$DOTFILES_DIR/zsh/core/04_plugins.zsh"

  # zinit 架构下，验证关键插件通过 zinit 加载
  assert_file_contains "zsh-syntax-highlighting 由 zinit 加载" "$plugins_file" "zsh-syntax-highlighting"

  assert_file_contains "zsh-autosuggestions 由 zinit 加载" "$plugins_file" "zsh-autosuggestions"

  # zinit light 模式用于只读插件
  assert_file_contains "使用 zinit light 加载只读插件" "$plugins_file" "zinit light"
}

test_plugin_find_fallback() {
  log_info "测试: zinit 插件管理（无 find 兜底）"
  local plugins_file="$DOTFILES_DIR/zsh/core/04_plugins.zsh"

  # zinit 架构下，插件加载由 zinit 管理，无需 find 兜底
  assert_file_contains "使用 zinit 加载插件" "$plugins_file" "zinit"

  assert_file_contains "包含 zinit ice 配置" "$plugins_file" "zinit ice"
}

test_plugin_error_messages() {
  log_info "测试: zinit 错误处理"
  local plugins_file="$DOTFILES_DIR/zsh/core/04_plugins.zsh"

  # zinit 架构下，验证错误处理机制
  assert_file_contains "包含 ZSH_DISABLE_PLUGINS 开关" "$plugins_file" "ZSH_DISABLE_PLUGINS"

  assert_file_contains "包含 list_plugins 辅助函数" "$plugins_file" "list_plugins"
}

# 动态模拟测试
test_install_simulated() {
  local ostype="${1:-Linux}"
  local arch="${2:-x86_64}"

  log_info "测试: install.sh 在 $ostype mock 环境中运行"

  setup_test_env "$ostype" "$arch"

  local install_script="$DOTFILES_DIR/zsh/install.sh"

  # 运行 install.sh (带超时保护，兼容 macOS 无 timeout 的情况)
  log_info "执行 install.sh..."
  local output runner
  if command -v timeout >/dev/null 2>&1; then
    runner=(timeout 30)
  elif command -v gtimeout >/dev/null 2>&1; then
    runner=(gtimeout 30)
  else
    runner=()
  fi
  if output=$(HOME="$TEST_DIR/home" PATH="$TEST_DIR/bin:$PATH" "${runner[@]}" bash "$install_script" 2>&1); then
    log_info "install.sh 执行完成"
  else
    local exit_code=$?
    log_warn "install.sh 退出码: $exit_code (可能是超时或预期的错误)"
  fi

  # 检查 .zshrc 链接创建
  if [[ -L "$TEST_DIR/home/.zshrc" ]]; then
    assert_pass "[$ostype] .zshrc 符号链接已创建"
  else
    assert_fail "[$ostype] .zshrc 符号链接未创建"
  fi

  # 检查 .zshenv 链接创建
  if [[ -L "$TEST_DIR/home/.zshenv" ]]; then
    assert_pass "[$ostype] .zshenv 符号链接已创建"
  else
    assert_fail "[$ostype] .zshenv 符号链接未创建"
  fi

  # 检查插件目录创建
  if [[ -d "$TEST_DIR/home/.dotfiles/zsh/plugins" ]]; then
    assert_pass "[$ostype] 插件目录已创建"
  else
    assert_fail "[$ostype] 插件目录未创建"
  fi

  # 检查输出中包含 "安装完成"
  if printf '%s\n' "$output" | grep -q "安装完成"; then
    assert_pass "[$ostype] 安装完成信息已输出"
  else
    assert_fail "[$ostype] 安装完成信息未输出"
  fi

  # 检查无 zinit 相关错误（注意: 正常输出会包含 "zinit"，只检查错误关键词）
  if printf '%s\n' "$output" | grep -qiE "zinit.*(失败|错误|error|fail|未安装)"; then
    assert_fail "[$ostype] 输出包含 zinit 错误信息"
  else
    assert_pass "[$ostype] 无 zinit 相关错误"
  fi

  # 验证 zoxide init.zsh 生成
  local zoxide_init="$TEST_DIR/home/.dotfiles/zsh/plugins/zoxide/init.zsh"
  if [[ -f "$zoxide_init" ]]; then
    local size
    size=$(wc -c < "$zoxide_init" 2>/dev/null || echo 0)
    if [[ "$size" -gt 0 ]]; then
      assert_pass "[$ostype] zoxide init.zsh 已生成且非空 (${size} bytes)"
    else
      assert_fail "[$ostype] zoxide init.zsh 为空文件"
    fi
  else
    log_warn "[$ostype] zoxide init.zsh 不存在 (mock zoxide 可能未正确触发)"
  fi

  cleanup_test_env
}

# ======================
# 主测试流程
# ======================

run_all_tests() {
  local mode="${1:-all}"

  printf "${BOLD}${CYAN}============================================${RESET}\n"
  printf "${BOLD}${CYAN}  Dotfiles 安装脚本测试器${RESET}\n"
  printf "${BOLD}${CYAN}  模式: %s${RESET}\n" "$mode"
  printf "${BOLD}${CYAN}============================================${RESET}\n"
  echo

  # === 静态分析测试 ===
  log_info "------ 静态分析测试 ------"

  test_install_sh_syntax
  test_all_zsh_syntax
  test_all_bash_syntax

  # P0 级
  test_zoxide_redirect_fix
  test_zinit_removal
  test_brewfile_fix

  # P1 级
  test_env_zsh_fixes
  test_plugins_fix
  test_starship_font_detection

  # P2 级
  test_zshenv_entry
  test_cross_platform_compat

  # P3 级 & 额外
  test_install_error_handling
  test_install_brew_fixes
  test_fallback_config_generation
  test_starship_toml_comments
  test_platform_files
  test_performance_script
  test_plugin_order
  test_plugin_find_fallback
  test_plugin_error_messages

  # === 动态模拟测试 ===
  if [[ "$mode" == "all" ]] || [[ "$mode" == "sim" ]]; then
    log_info "------ 动态模拟测试 ------"

    test_install_simulated "Linux" "x86_64"
    test_install_simulated "Darwin" "arm64"
    test_install_simulated "Darwin" "x86_64"
  fi

  # === 报告 ===
  echo
  printf "${BOLD}${CYAN}============================================${RESET}\n"
  printf "${BOLD}${CYAN}  测试报告${RESET}\n"
  printf "${BOLD}${CYAN}============================================${RESET}\n"
  echo

  printf "  总计: ${BOLD}%s${RESET}\n" "$TOTAL"
  printf "  ${GREEN}通过: %s${RESET}\n" "$PASS"
  printf "  ${RED}失败: %s${RESET}\n" "$FAIL"

  local rate=0
  if [[ $TOTAL -gt 0 ]]; then
    rate=$((PASS * 100 / TOTAL))
  fi
  printf "  通过率: %s%%\n" "$rate"

  if [[ $FAIL -gt 0 ]]; then
    echo
    printf "${RED}失败用例:${RESET}\n"
    for t in "${FAILED_TESTS[@]}"; do
      printf "  ${RED}• %s${RESET}\n" "$t"
    done
  fi

  echo
  if [[ $FAIL -eq 0 ]]; then
    printf "${GREEN}${BOLD}🎉 所有测试通过！${RESET}\n"
  else
    printf "${RED}${BOLD}❌ 有 %s 个测试失败${RESET}\n" "$FAIL"
  fi

  return $FAIL
}

# ======================
# 入口
# ======================

case "${1:-all}" in
  static)
    run_all_tests "static"
    ;;
  sim)
    run_all_tests "sim"
    ;;
  all)
    run_all_tests "all"
    ;;
  *)
    printf '用法: %s {all|static|sim}\n' "$0"
    printf '%s\n' "  static - 仅静态代码分析"
    printf '%s\n' "  sim    - 仅动态模拟测试"
    printf '%s\n' "  all    - 全部测试（默认）"
    exit 1
    ;;
esac