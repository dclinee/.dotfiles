#!/usr/bin/env bash
# ======================
# lib/symlink.sh 单元测试
# ======================

set -eo pipefail

DOTFILES_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0; TOTAL=0; FAILED_TESTS=()

RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'; BLUE='\033[34m'; CYAN='\033[36m'; RESET='\033[0m'; BOLD='\033[1m'

log_ok()   { printf "${GREEN}[OK]${RESET} %s\n" "$*"; }
log_err()  { printf "${RED}[FAIL]${RESET} %s\n" "$*"; }
assert_pass() { PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); log_ok "$*"; }
assert_fail() { FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); FAILED_TESTS+=("$*"); log_err "$*"; }

# 加载 lib
source "${DOTFILES_ROOT}/lib/output.sh"
source "${DOTFILES_ROOT}/lib/symlink.sh"

# 临时测试目录
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

# 测试 1: 源存在、目标不存在 → 创建链接
test_symlink_create() {
  local src="${TMP_DIR}/src1.txt"
  local dst="${TMP_DIR}/dst1.txt"
  echo "content" > "$src"
  safe_symlink "$src" "$dst" 2>/dev/null
  if [[ -L "$dst" ]] && [[ "$(_resolve_link "$dst")" == "$(_resolve_link "$src")" ]]; then
    assert_pass "safe_symlink: 源存在目标不存在 → 创建链接"
  else
    assert_fail "safe_symlink: 源存在目标不存在 → 创建链接"
  fi
}

# 测试 2: 目标已是正确链接 → 跳过
test_symlink_skip() {
  local src="${TMP_DIR}/src2.txt"
  local dst="${TMP_DIR}/dst2.txt"
  echo "content" > "$src"
  ln -sf "$src" "$dst"
  safe_symlink "$src" "$dst" 2>/dev/null
  if [[ -L "$dst" ]]; then
    assert_pass "safe_symlink: 目标已是正确链接 → 跳过"
  else
    assert_fail "safe_symlink: 目标已是正确链接 → 跳过"
  fi
}

# 测试 3: dry-run 模式 → 不落地
test_symlink_dry_run() {
  local src="${TMP_DIR}/src3.txt"
  local dst="${TMP_DIR}/dst3.txt"
  echo "content" > "$src"
  DRY_RUN=true safe_symlink "$src" "$dst" 2>/dev/null
  if [[ ! -e "$dst" ]]; then
    assert_pass "safe_symlink: dry-run → 不落地"
  else
    assert_fail "safe_symlink: dry-run → 不落地"
  fi
}

# 测试 4: 目标存在 → 备份后重建
test_symlink_backup() {
  local src="${TMP_DIR}/src4.txt"
  local dst="${TMP_DIR}/dst4.txt"
  echo "new" > "$src"
  echo "old" > "$dst"
  safe_symlink "$src" "$dst" 2>/dev/null
  if [[ -L "$dst" ]] && ls "${dst}.bak."* >/dev/null 2>&1; then
    assert_pass "safe_symlink: 目标存在 → 备份后重建"
  else
    assert_fail "safe_symlink: 目标存在 → 备份后重建"
  fi
}

# 测试 5: 源不存在 → warning + return 1
test_symlink_no_source() {
  local src="${TMP_DIR}/nonexistent.txt"
  local dst="${TMP_DIR}/dst5.txt"
  if safe_symlink "$src" "$dst" 2>/dev/null; then
    assert_fail "safe_symlink: 源不存在 → 应返回非零"
  else
    assert_pass "safe_symlink: 源不存在@存在 → 返回非零"
  fi
}

# 执行
test_symlink_create
test_symlink_skip
test_symlink_dry_run
test_symlink_backup
test_symlink_no_source

# 汇总
echo ""
printf "${BOLD}=== lib/symlink.sh 测试结果 ===${RESET}\n"
printf "${GREEN}通过: ${PASS}${RESET}  ${RED}失败: ${FAIL}${RESET}  总计: ${TOTAL}\n"
if [[ $FAIL -gt 0 ]]; then
  exit 1
fi