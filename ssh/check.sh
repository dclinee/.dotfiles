#!/usr/bin/env bash

# ======================
# SSH 环境体检
# ======================
#
# 功能:
#   1. 检查 ssh 客户端版本
#   2. 验证配置软链
#   3. 检查配置语法（ssh -G 解析）
#   4. 检查关键目录与文件权限
#   5. 检查密钥与私有配置存在性

set -euo pipefail

# shellcheck source=/dev/null
source "$(dirname "$0")/_common.sh"

# 初始化体检计数器
check_init

# ======================
# 检查核心工具
# ======================
check_core_tools() {
  echo_step "核心工具"

  if has_ssh; then
    check_ok "ssh: $(get_ssh_version)"
  else
    check_fail "ssh: 未安装（一般系统已内置 OpenSSH）"
  fi
}

# ======================
# 检查配置软链
# ======================
check_configs() {
  echo_step "配置文件软链"

  local configs=(
    "${HOME}/.ssh/config|${SSH_DIR}/config"
  )

  check_symlinks "${configs[@]}"
}

# ======================
# 检查配置文件语法
# ======================
check_syntax() {
  echo_step "配置文件语法（ssh -G 解析）"

  if ! has_ssh; then
    check_skip "ssh 未安装，跳过语法检查"
    return 0
  fi

  # ssh -F 显式指定已安装的配置，-G 仅解析并输出生效选项，不发起连接（OpenSSH >= 7.3）
  if ssh -F "${HOME}/.ssh/config" -G github.com > /dev/null 2>&1; then
    check_ok "语法通过: ~/.ssh/config"
  else
    check_fail "语法错误: ssh -G github.com 解析失败"
  fi
}

# ======================
# 检查权限
# ======================
check_permissions() {
  echo_step "目录与文件权限"

  # ~/.ssh 与 sockets 目录应为 700
  local dir
  for dir in "${HOME}/.ssh" "${HOME}/.ssh/sockets"; do
    if [[ -d "${dir}" ]]; then
      local mode
      mode="$(get_file_mode "${dir}")"
      if [[ "${mode}" == "700" ]]; then
        check_ok "$(basename "${dir}") 权限正确 (700)"
      else
        check_warn "$(basename "${dir}") 权限为 ${mode}（建议 700）"
      fi
    else
      check_fail "目录不存在: ${dir}"
    fi
  done

  # 配置与私钥权限（软链会跟随到目标文件）
  # config 类文件仅要求"组/其他用户不可写"（644 即可）；私钥严格要求 600
  local f mode
  for f in "${HOME}/.ssh/config" "${HOME}/.ssh/config.local" "${HOME}/.ssh/id_ed25519"; do
    if [[ -e "${f}" ]]; then
      mode="$(get_file_mode "${f}")"
      if [[ ! "${mode}" =~ ^[0-7]{3,4}$ ]]; then
        check_warn "$(basename "${f}") 无法读取权限位（mode: ${mode}）"
      elif (( 8#${mode} & 8#022 )); then
        check_warn "$(basename "${f}") 组/其他用户可写（mode: ${mode}），建议: chmod 600 ${f}"
      elif [[ "${mode}" == "600" ]]; then
        check_ok "$(basename "${f}") 权限正确 (600)"
      else
        check_ok "$(basename "${f}") 权限合理 (${mode})"
      fi
    else
      check_skip "未创建（可选）: $(basename "${f}")"
    fi
  done
}

# ======================
# 检查密钥与私有配置
# ======================
check_keys() {
  echo_step "密钥与私有配置"

  if [[ -f "${HOME}/.ssh/id_ed25519" ]]; then
    check_ok "默认密钥存在: ~/.ssh/id_ed25519"
  else
    check_warn "默认密钥不存在（可执行: bash ssh/install.sh --gen-key）"
  fi

  if [[ -f "${HOME}/.ssh/config.local" ]]; then
    check_ok "本机私有配置存在: ~/.ssh/config.local"
  else
    check_warn "本机私有配置缺失（install.sh 会自动创建模板）"
  fi
}

# ======================
# 主流程
# ======================
main() {
  echo_title "SSH 环境体检"

  check_core_tools;  echo_separator
  check_configs;     echo_separator
  check_syntax;      echo_separator
  check_permissions; echo_separator
  check_keys

  # 复用 check_summary（内部会根据 FAIL 决定是否 exit 1）
  check_summary
}

main
