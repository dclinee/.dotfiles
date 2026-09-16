#!/usr/bin/env bash
# ======================
# lib/common.sh 单元测试
# ======================

set -eo pipefail

DOTFILES_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0; TOTAL=0; FAILED_TESTS=()

RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'; BLUE='\033[34m'; CYAN='\033[36m'; RESET='\033[0m'; BOLD='\033[1m'

log_ok()   { printf "${GREEN}[OK]${RESET} %s\n" "$*"; }
log_err()  { printf "${RED}[FAIL]${RESET} %s\n" "$*"; }
assert_pass() { PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); log_ok "$*"; }
assert_fail() { FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); FAILED_TESTS+=("$*"); log_err "$*"; }

source "${DOTFILES_ROOT}/lib/common.sh"

# 测试 is_dry_run
test_is_dry_run_true() {
  DRY_RUN=true
  if is_dry_run; then
    assert_pass "is_dry_run: DRY_RUN=true → true"
  else
    assert_fail "is_dry_run: DRY_RUN=true → true"
  fi
  unset DRY_RUN
}

test_is_dry_run_false() {
  DRY_RUN=false
  if is_dry_run; then
    assert_fail "is_dry_run: DRY_RUN=false → false"
  else
    assert_pass "is_dry_run: DRY_RUN=false → false"
  fi
  unset DRY_RUN
}

test_is_dry_run_unset() {
  unset DRY_RUN
  if is_dry_run; then
    assert_fail "is_dry_run: DRY_RUN 未设置 → false"
  else
    assert_pass "is_dry_run: DRY_RUN 未设置 → false"
  fi
}

# 测试 has_cmd
test_has_cmd_exists() {
  if has_cmd ls; then
    assert_pass "has_cmd: ls 存在 → true"
  else
    assert_fail "has_cmd: ls 存在 → true"
  fi
}

test_has_cmd_not_exists() {
  if has_cmd __nonexistent_cmd__; then
    assert_fail "has_cmd: __nonexistent_cmd__ 不存在 → false"
  else
    assert_pass "has_cmd: __nonexistent_cmd__ 不存在 → false"
  fi
}

# 测试 read_tools_list
test_read_tools_list() {
  local tmp_list
  tmp_list="$(mktemp)"
  trap 'rm -f "${tmp_list}"' EXIT
  cat > "$tmp_list" <<EOF
# 注释行
ruff|0.6.0
mypy

black|24.8.0
EOF
  local result
  result=$(read_tools_list "$tmp_list")
  local count
  count=$(echo "$result" | wc -l | tr -d ' ')
  if [[ "$count" == "3" ]]; then
    assert_pass "read_tools_list: 正确解析 3 行（跳过注释和空行）"
  else
    assert_fail "read_tools_list: 应解析 3 行，实际 ${count}"
  fi
}

# 执行
test_is_dry_run_true
test_is_dry_run_false
test_is_dry_run_unset
test_has_cmd_exists
test_has_cmd_not_exists
test_read_tools_list

# 汇总
echo ""
printf "${BOLD}=== lib/common.sh 测试结果 ===${RESET}\n"
printf "${GREEN}通过: ${PASS}${RESET}  ${RED}失败: ${FAIL}${RESET}  总计: ${TOTAL}\n"
if [[ $FAIL -gt 0 ]]; then
  exit 1
fi