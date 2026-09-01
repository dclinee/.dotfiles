#!/usr/bin/env bash

# ======================
# SSH 配置安装器
# ======================
#
# 功能:
#   1. 检查 ssh 客户端
#   2. 创建 ~/.ssh 目录（权限 700）与 ControlPath sockets 目录
#   3. 软链 ~/.ssh/config → ssh/config
#   4. 创建 ~/.ssh/config.local 模板（本机私有配置，不提交仓库）
#   5. --gen-key 可选生成本机 ed25519 密钥（多台机器各生成独立密钥）
#
# 用法:
#   ./install.sh              # 常规安装
#   ./install.sh --gen-key    # 安装 + 生成密钥（已存在则跳过）

set -euo pipefail

# shellcheck source=/dev/null
source "$(dirname "$0")/_common.sh"

GEN_KEY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --gen-key) GEN_KEY=true; shift ;;
    -h|--help)
      printf '用法: %s [--gen-key]\n' "$(basename "$0")"
      printf '%s\n' "  --gen-key 生成本机 ed25519 密钥（已存在则跳过）"
      exit 0 ;;
    *) printf '未知参数: %s\n' "$1"; exit 1 ;;
  esac
done

# ======================
# 检查 ssh 客户端
# ======================
check_ssh_client() {
  if ! has_ssh; then
    echo_warning "ssh 未安装，仅创建配置文件（一般系统已内置 OpenSSH）"
    echo_warning "  macOS:   xcode-select --install"
    echo_warning "  Linux:   sudo apt install openssh-client / sudo dnf install openssh-clients"
    return 1
  fi
  echo_success "ssh 已安装: $(get_ssh_version)"
}

# ======================
# 创建目录结构
# ======================
create_dirs() {
  echo_step "创建必要目录..."

  # ~/.ssh 标准权限为 700（已存在也强制纠正）
  mkdir -p "${HOME}/.ssh"
  chmod 700 "${HOME}/.ssh"

  # ControlPath sockets 目录（10-core.conf 中 ControlPath 使用）
  mkdir -p "${HOME}/.ssh/sockets"
  chmod 700 "${HOME}/.ssh/sockets"

  echo_success "目录创建完成（~/.ssh、~/.ssh/sockets，权限 700）"
}

# ======================
# 创建配置链接
# ======================
link_config() {
  echo_step "创建 SSH 配置链接..."
  safe_symlink "${SSH_DIR}/config" "${HOME}/.ssh/config" || true

  # 验证链接
  echo_step "验证配置链接..."
  ls -la "${HOME}/.ssh/config"
}

# ======================
# 创建本机私有配置模板
# ======================
create_local_template() {
  local local_config="${HOME}/.ssh/config.local"
  if [[ -f "${local_config}" ]]; then
    echo_success "config.local 已存在: ${local_config}"
    return 0
  fi

  cat > "${local_config}" << 'SSHLOCAL_EOF'
# SSH 本机私有配置（不提交到仓库）
# 用于: 本机专属主机、独立密钥、代理跳板等机器差异配置
#
# 示例:
# Host work-server
#     HostName 10.0.0.2
#     User ops
#     IdentityFile ~/.ssh/id_ed25519_work
#     ProxyJump bastion
SSHLOCAL_EOF

  chmod 600 "${local_config}"
  echo_warning "已创建 ~/.ssh/config.local 模板，可按需编辑"
  echo "  vim ~/.ssh/config.local"
}

# ======================
# 生成本机密钥（多台机器各自独立）
# ======================
generate_key() {
  if ! $GEN_KEY; then
    return 0
  fi

  echo_step "生成本机 ed25519 密钥..."

  local key_file="${HOME}/.ssh/id_ed25519"
  if [[ -f "${key_file}" ]]; then
    echo_skip "密钥已存在: ${key_file}"
    return 0
  fi

  # 多机部署: 注释带上 用户@主机名，便于在 GitHub / 服务器上区分来源
  local machine_name
  machine_name=$(hostname -s 2>/dev/null || echo "unknown-host")
  ssh-keygen -t ed25519 -C "${USER}@${machine_name}" -f "${key_file}" -N ""
  chmod 600 "${key_file}"
  chmod 644 "${key_file}.pub"

  echo_success "密钥已生成: ${key_file}"
  echo_detail "公钥内容（添加到 GitHub → SSH keys，或远程服务器 ~/.ssh/authorized_keys）:"
  cat "${key_file}.pub"
}

# ======================
# 验证配置可解析
# ======================
verify_install() {
  echo_step "验证配置解析（ssh -G 不发起连接）..."
  # -F 显式指定刚安装的配置，避免受运行环境 HOME 差异影响
  if ssh -F "${HOME}/.ssh/config" -G github.com > /dev/null 2>&1; then
    echo_success "配置解析通过"
    echo_detail "github.com 实际生效配置:"
    ssh -F "${HOME}/.ssh/config" -G github.com 2>/dev/null | grep -iE '^(hostname|port|user) ' | while read -r line; do
      echo_detail "  ${line}"
    done
  else
    echo_warning "ssh -G 解析失败（OpenSSH < 7.3 不支持 -G，可忽略）"
  fi
}

# 主安装流程
main() {
  check_ssh_client || true

  create_dirs
  link_config
  create_local_template
  generate_key
  verify_install

  echo_title "安装完成"
  printf "${GREEN}${CHECK} ${BOLD}SSH 配置安装完成！${RESET}\n"
  printf "${BOLD}${YELLOW}${ARROW} 配置位置:${RESET} %s/config（目录分片 config.d/ + platform/）\n" "${SSH_DIR}"
  printf "${BOLD}${YELLOW}${ARROW} 链接位置:${RESET} %s/.ssh/config\n" "${HOME}"
  printf "${BOLD}${YELLOW}${ARROW} 本机私有配置:${RESET} %s/.ssh/config.local（不提交仓库）\n" "${HOME}"
  if ! $GEN_KEY; then
    printf "${BOLD}${YELLOW}${ARROW} 生成密钥:${RESET} bash %s/install.sh --gen-key\n" "${SSH_DIR}"
  fi
  echo_separator
}

# 执行主流程
main
