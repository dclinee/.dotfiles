#!/usr/bin/env bash

# ======================
# Git 配置安装器
# ======================

set -euo pipefail
LOG_FILE="/tmp/dotfiles_install_$(date +%Y%m%d_%H%M%S).log"

# shellcheck source=/dev/null
source "$(dirname "$0")/_common.sh"

GIT_HOME="${GIT_DIR}"

main() {
  echo_title "Git 配置安装器"
  printf '安装日志将保存到: %s\n' "${LOG_FILE}"

  echo_step "安装 Git 配置..."

  # .gitconfig
  safe_symlink "${GIT_HOME}/.gitconfig" "${HOME}/.gitconfig" || true

  # .gitignore_global
  safe_symlink "${GIT_HOME}/.gitignore_global" "${HOME}/.gitignore_global" || true

  # .gitattributes
  safe_symlink "${GIT_HOME}/.gitattributes" "${HOME}/.gitattributes" || true

  echo_success "Git 配置已链接"

  # 创建 .gitconfig.local 模板（如不存在）
  local local_config="${HOME}/.gitconfig.local"
  if [[ ! -f "${local_config}" ]]; then
    if is_dry_run; then
      echo_detail "[dry-run] 将创建模板: ${local_config}"
    else
    cat > "${local_config}" << 'GITLOCAL_EOF'
# Git 个人配置（不提交到仓库）
# 请修改以下信息为你自己的（替换 YOUR_NAME / YOUR_EMAIL）

[user]
    name = YOUR_NAME
    email = YOUR_EMAIL

# 可在此添加其他个人配置，如：
# [commit]
#     gpgsign = true
# [user]
#     signingkey = YOUR_GPG_KEY
GITLOCAL_EOF
      echo_warning "已创建 ~/.gitconfig.local 模板，请修改其中的用户信息"
      echo "  vim ~/.gitconfig.local"
    fi
  else
    echo_success ".gitconfig.local 已存在"
  fi

  # 验证用户信息是否已配置（匹配所有占位符变体）
  local current_name
  current_name=$(git config user.name 2>/dev/null || echo "")
  if [[ -z "${current_name}" ]] || \
     [[ "${current_name}" == "YOUR_NAME" ]] || \
     [[ "${current_name}" == "Your Name" ]]; then
    echo_warning "Git 用户信息未配置，请编辑 ~/.gitconfig.local"
  fi

  echo_success "Git 配置安装完成"
}

main
