#!/usr/bin/env bash

# ============================================================
# Dotfiles Docker 模块 - 构建 / 启动 / 停止 / 日志 / 清理
# ============================================================
#
# 用法：
#   ./build.sh build [service]    构建镜像（dev / ubuntu / debian / fedora / validate / test）
#   ./build.sh up   [service]    启动容器
#   ./build.sh down               停止并移除所有容器
#   ./build.sh logs [service]    查看日志
#   ./build.sh clean              清理容器 + 镜像 + 卷
#   ./build.sh shell [service]   进入容器 shell（默认 dev）
#   ./build.sh test  [service]   运行集成测试（默认 test）
#   ./build.sh validate          运行静态验证

set -euo pipefail

LOG_FILE="/tmp/dotfiles_docker_$(date +%Y%m%d_%H%M%S).log"

# shellcheck source=/dev/null
source "$(dirname "$0")/_common.sh"

COMPOSE_FILE="${DOCKER_DIR}/docker-compose.yml"
COMPOSE_CMD=(docker compose -f "${COMPOSE_FILE}")

# 优先用 docker compose v2
if ! docker compose version > /dev/null 2>&1; then
  if has_cmd docker-compose; then
    COMPOSE_CMD=(docker-compose -f "${COMPOSE_FILE}")
  else
    printf 'ERROR: 需要 docker compose v2 或 docker-compose\n' >&2
    exit 1
  fi
fi

_load_env() {
  if [[ -f "${DOCKER_DIR}/.env" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "${DOCKER_DIR}/.env"
    set +a
  fi
}

_build() {
  local service="${1:-}"
  echo_step "构建 Docker 镜像..."
  if [[ -n "${service}" ]]; then
    "${COMPOSE_CMD[@]}" build "${service}" 2>>"${LOG_FILE}"
  else
    "${COMPOSE_CMD[@]}" build 2>>"${LOG_FILE}"
  fi
  echo_success "构建完成"
}

_up() {
  local service="${1:-dev}"
  echo_step "启动 ${service}..."
  if [[ "${service}" == "dev" ]]; then
    # dev 服务通常需要交互式进入，用 run
    "${COMPOSE_CMD[@]}" run --rm dev 2>>"${LOG_FILE}"
  else
    "${COMPOSE_CMD[@]}" run --rm "${service}" 2>>"${LOG_FILE}"
  fi
}

_down() {
  echo_step "停止并移除容器..."
  "${COMPOSE_CMD[@]}" down 2>>"${LOG_FILE}" || true
  echo_success "已停止"
}

_logs() {
  local service="${1:-}"
  if [[ -n "${service}" ]]; then
    "${COMPOSE_CMD[@]}" logs -f --tail=100 "${service}" 2>>"${LOG_FILE}"
  else
    "${COMPOSE_CMD[@]}" logs -f --tail=100 2>>"${LOG_FILE}"
  fi
}

_clean() {
  echo_step "清理 Docker 资源..."
  "${COMPOSE_CMD[@]}" down -v --rmi local 2>>"${LOG_FILE}" || true
  # 删除 dangling 镜像
  docker image prune -f 2>>"${LOG_FILE}" || true
  echo_success "清理完成"
}

_shell() {
  local service="${1:-dev}"
  echo_step "进入 ${service} 的 shell..."
  if [[ "${service}" == "dev" ]]; then
    "${COMPOSE_CMD[@]}" run --rm dev zsh -l 2>>"${LOG_FILE}"
  else
    "${COMPOSE_CMD[@]}" run --rm --profile test "${service}" zsh -l 2>>"${LOG_FILE}"
  fi
}

_validate() {
  echo_step "运行静态验证..."
  "${COMPOSE_CMD[@]}" run --rm --profile validate validate 2>>"${LOG_FILE}"
}

_run_test() {
  local service="${1:-test}"
  echo_step "运行集成测试..."
  if [[ "${service}" == "test" ]]; then
    "${COMPOSE_CMD[@]}" run --rm --profile test-run test 2>>"${LOG_FILE}"
  else
    # 在指定发行版容器里手动跑 test_integration.sh
    "${COMPOSE_CMD[@]}" run --rm --profile test "${service}" \
      zsh -c 'bash ~/.dotfiles/tests/test_integration.sh' 2>>"${LOG_FILE}"
  fi
}

_usage() {
  cat << 'EOF'
用法: ./build.sh <命令> [参数]

命令:
  build [service]    构建镜像 (dev|ubuntu|debian|fedora|validate|test)
  up   [service]    启动容器 (默认 dev)
  down               停止并移除容器
  logs [service]    查看日志
  clean              清理容器 + 镜像 + 卷
  shell [service]   进入容器 shell (默认 dev)
  validate           运行静态验证
  test  [service]   运行集成测试 (默认 test)
  help               显示本帮助

环境变量:
  NO_MIRROR=1        禁用所有国内镜像源
  APT_MIRROR=...     自定义 apt 镜像源
  BASE_IMAGE=...     自定义基础镜像 (默认 ubuntu:24.04)
EOF
}

main() {
  _load_env

  local cmd="${1:-help}"
  local arg="${2:-}"

  case "${cmd}" in
    build)    _build "${arg}" ;;
    up)       _up "${arg}" ;;
    down)     _down ;;
    logs)     _logs "${arg}" ;;
    clean)    _clean ;;
    shell)    _shell "${arg}" ;;
    validate) _validate ;;
    test)     _run_test "${arg}" ;;
    help|-h|--help) _usage ;;
    *)        _usage; exit 1 ;;
  esac
}

main "$@"
