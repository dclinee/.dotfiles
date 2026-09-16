#!/usr/bin/env bash
# 本文件由调用者 source，预期调用者已设置 set -euo pipefail

# ======================
# 公共网络下载函数库
# ======================
#
# 提供统一的网络下载/克隆/脚本执行函数，内置镜像回退策略：
#   1. dotfiles_curl          — 带超时 + 镜像回退的 curl
#   2. dotfiles_clone         — 带浅克隆 + 镜像回退的 git clone
#   3. dotfiles_install_script — 下载安装脚本到临时文件并执行
#
# 镜像策略（三级回退）:
#   原始源 → 镜像1 (ghproxy.net) → 镜像2 (gh-proxy.com)
#
# 环境变量:
#   NO_MIRROR          — 设置后禁用所有镜像，仅走官方源
#   DOTFILES_GH_PROXY  — 自定义代理前缀（覆盖默认 ghproxy 列表）
#   DOTFILES_CURL_CONNECT_TIMEOUT — 连接超时秒数（默认 15）
#   DOTFILES_CURL_MAX_TIME        — 最大传输秒数（默认 60）
#
# 依赖: lib/output.sh 中的 echo_warning / echo_detail（通过 lib/common.sh 自动加载）
#
# 使用方法:
#   source "${DOTFILES_ROOT}/lib/net.sh"
#   dotfiles_curl "https://starship.rs/install.sh" -o /tmp/install.sh
#   dotfiles_clone "https://github.com/foo/bar.git" ~/bar --depth 1
#   dotfiles_install_script "https://astral.sh/uv/install.sh"

if [[ -z "${__NET_SH_LOADED:-}" ]]; then
__NET_SH_LOADED=1

# ======================
# 镜像源配置
# ======================

# 输出 GitHub 代理前缀列表（每行一个，供调用方遍历）
# 优先级: DOTFILES_GH_PROXY > 默认 ghproxy 列表
# NO_MIRROR 设置时输出空（仅走原始源）
dotfiles_gh_proxies() {
  if [[ -n "${NO_MIRROR:-}" ]]; then
    return 0
  fi
  if [[ -n "${DOTFILES_GH_PROXY:-}" ]]; then
    printf '%s\n' "${DOTFILES_GH_PROXY}"
  else
    printf '%s\n' \
      "https://ghproxy.net/" \
      "https://gh-proxy.com/"
  fi
}

# 构建完整 URL 列表（原始 + 代理前缀拼接），每行一个
# 用法: _net_build_urls <url>
_net_build_urls() {
  local url="$1"
  printf '%s\n' "${url}"
  if [[ -n "${NO_MIRROR:-}" ]]; then
    return 0
  fi
  local proxy
  while IFS= read -r proxy; do
    [[ -z "${proxy}" ]] && continue
    printf '%s%s\n' "${proxy}" "${url}"
  done < <(dotfiles_gh_proxies)
}

# ======================
# curl 超时参数
# ======================
_net_curl_timeout_args() {
  local connect_timeout="${DOTFILES_CURL_CONNECT_TIMEOUT:-15}"
  local max_time="${DOTFILES_CURL_MAX_TIME:-60}"
  printf -- '--connect-timeout %s --max-time %s' "${connect_timeout}" "${max_time}"
}

# ======================
# dotfiles_curl — 带镜像回退的 curl
# ======================
#
# 用法: dotfiles_curl <url> [curl-args...]
# 默认添加超时参数（可通过 DOTFILES_CURL_* 调整）
# 镜像回退: 原始源失败 → 代理1 → 代理2
# 返回值: 第一个成功的 curl 的退出码（通常 0）；全部失败返回 1
#
# 注意: 调用方应自行指定 -o <file> 或 -O，否则内容输出到 stdout
dotfiles_curl() {
  local url="$1"
  shift

  local connect_timeout="${DOTFILES_CURL_CONNECT_TIMEOUT:-15}"
  local max_time="${DOTFILES_CURL_MAX_TIME:-60}"
  local timeout_args=(--connect-timeout "${connect_timeout}" --max-time "${max_time}")

  local try_url rc
  while IFS= read -r try_url; do
    [[ -z "${try_url}" ]] && continue
    if curl -fsSL "${timeout_args[@]}" "${try_url}" "$@" 2>/dev/null; then
      return 0
    fi
    rc=$?
  done < <(_net_build_urls "${url}")

  echo_warning "所有源均下载失败: ${url}"
  return 1
}

# ======================
# dotfiles_clone — 带镜像回退的 git clone
# ======================
#
# 用法: dotfiles_clone <url> <dest> [git-args...]
# 镜像回退: 原始源失败 → 代理1 → 代理2
# 默认使用 --depth 1 浅克隆（可通过参数覆盖）
# 返回值: 成功返回 0；全部失败返回 1
dotfiles_clone() {
  local url="$1"
  local dest="$2"
  shift 2

  local try_url
  while IFS= read -r try_url; do
    [[ -z "${try_url}" ]] && continue
    if git clone --depth 1 "${try_url}" "${dest}" "$@" 2>/dev/null; then
      return 0
    fi
    rm -rf "${dest}" 2>/dev/null || true
  done < <(_net_build_urls "${url}")

  echo_warning "所有源均克隆失败: ${url}"
  return 1
}

# ======================
# dotfiles_install_script — 下载并执行安装脚本
# ======================
#
# 用法: dotfiles_install_script <url> [script-args...]
# 替代 curl ... | bash 模式: 先下载到临时文件再执行
# 镜像回退: 原始源失败 → 代理1 → 代理2
# 返回值: 脚本执行的退出码；下载失败返回 1
#
# 日志: 通过 LOG_FILE 变量（若已设置）重定向 stderr
dotfiles_install_script() {
  local url="$1"
  shift

  local tmp_file
  tmp_file="$(mktemp)"
  local _net_tmp="${tmp_file}"
  trap "rm -f '${_net_tmp}'" EXIT RETURN

  local connect_timeout="${DOTFILES_CURL_CONNECT_TIMEOUT:-15}"
  local max_time="${DOTFILES_CURL_MAX_TIME:-300}"
  local timeout_args=(--connect-timeout "${connect_timeout}" --max-time "${max_time}")

  local try_url downloaded=false
  while IFS= read -r try_url; do
    [[ -z "${try_url}" ]] && continue
    if curl -fsSL "${timeout_args[@]}" "${try_url}" -o "${tmp_file}" 2>/dev/null; then
      downloaded=true
      break
    fi
  done < <(_net_build_urls "${url}")

  if [[ "${downloaded}" != true ]]; then
    echo_warning "所有源均下载失败: ${url}"
    rm -f "${tmp_file}"
    trap - EXIT RETURN
    return 1
  fi

  local log_redirect=""
  if [[ -n "${LOG_FILE:-}" ]]; then
    log_redirect="2>>${LOG_FILE}"
  fi

  local rc=0
  # shellcheck disable=SC2086
  bash "${tmp_file}" "$@" ${log_redirect} || rc=$?
  rm -f "${tmp_file}"
  trap - EXIT RETURN
  return "${rc}"
}

fi  # __NET_SH_LOADED