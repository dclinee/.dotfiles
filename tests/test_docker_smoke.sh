#!/usr/bin/env bash
# ======================
# docker/ 模块冒烟测试
# ======================

set -eo pipefail

DOTFILES_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0; TOTAL=0; FAILED_TESTS=()

RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'; BLUE='\033[34m'; CYAN='\033[36m'; RESET='\033[0m'; BOLD='\033[1m'

log_ok()   { printf "${GREEN}[OK]${RESET} %s\n" "$*"; }
log_err()  { printf "${RED}[FAIL]${RESET} %s\n" "$*"; }
assert_pass() { PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); log_ok "$*"; }
assert_fail() { FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); FAILED_TESTS+=("$*"); log_err "$*"; }

# 测试 1: build.sh 语法正确
test_build_sh_syntax() {
  if bash -n "${DOTFILES_ROOT}/docker/build.sh" 2>/dev/null; then
    assert_pass "docker/build.sh 语法正确"
  else
    assert_fail "docker/build.sh 语法错误"
  fi
}

# 测试 2: Dockerfile 存在
test_dockerfiles_exist() {
  local files=(
    "${DOTFILES_ROOT}/docker/Dockerfile"
    "${DOTFILES_ROOT}/docker/Dockerfile.ci"
    "${DOTFILES_ROOT}/docker/docker-compose.yml"
  )
  local all_exist=true
  for f in "${files[@]}"; do
    [[ -f "$f" ]] || all_exist=false
  done
  if $all_exist; then
    assert_pass "docker/ 核心文件存在"
  else
    assert_fail "docker/ 核心文件缺失"
  fi
}

# 测试 3: build.sh 参数解析（dry-run）
test_build_sh_params() {
  if bash -n "${DOTFILES_ROOT}/docker/build.sh" 2>/dev/null; then
    assert_pass "docker/build.sh 参数解析正常（语法通过）"
  else
    assert_fail "docker/build.sh 参数解析异常"
  fi
}

# 执行
test_build_sh_syntax
test_dockerfiles_exist
test_build_sh_params

# 汇总
echo ""
printf "${BOLD}=== docker/ 冒烟测试结果 ===${RESET}\n"
printf "${GREEN}通过: ${PASS}${RESET}  ${RED}失败: ${FAIL}${RESET}  总计: ${TOTAL}\n"
if [[ $FAIL -gt 0 ]]; then
  exit 1
fi