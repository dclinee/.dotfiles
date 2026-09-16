#!/usr/bin/env bash
# ======================
# lib/net.sh 单元测试
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

# 测试 dotfiles_gh_proxies
test_gh_proxies_normal() {
  unset NO_MIRROR
  local proxies
  proxies=$(dotfiles_gh_proxies 2>/dev/null || true)
  if echo "$proxies" | grep -q "ghproxy.net" && echo "$proxies" | grep -q "gh-proxy.com"; then
    assert_pass "dotfiles_gh_proxies: 正常模式输出 ghproxy.net 和 gh-proxy.com"
  else
    assert_fail "dotfiles_gh_proxies: 正常模式应输出 ghproxy.net 和 gh-proxy.com"
  fi
}

test_gh_proxies_no_mirror() {
  NO_MIRROR=1
  local proxies
  proxies=$(dotfiles_gh_proxies 2>/dev/null || true)
  if [[ -z "$proxies" ]]; then
    assert_pass "dotfiles_gh_proxies: NO_MIRROR=1 → 输出为空"
  else
    assert_fail "dotfiles_gh_proxies: NO_MIRROR=1 应输出为空"
  fi
  unset NO_MIRROR
}

# 执行
test_gh_proxies_normal
test_gh_proxies_no_mirror

# 汇总
echo ""
printf "${BOLD}=== lib/net.sh 测试结果 ===${RESET}\n"
printf "${GREEN}通过: ${PASS}${RESET}  ${RED}失败: ${FAIL}${RESET}  总计: ${TOTAL}\n"
if [[ $FAIL -gt 0 ]]; then
  exit 1
fi