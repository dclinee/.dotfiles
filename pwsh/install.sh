#!/usr/bin/env bash

# ======================
# PowerShell 模块安装器（bash 侧封装）
# ======================
#
# 供 bootstrap.sh / Makefile 统一调度，实际逻辑在 install.ps1。
# - 优先调用 pwsh（PowerShell 7+），回退 powershell（Windows 自带 5.1）
# - WSL 下只接受 Linux 原生 pwsh，避免误用 Windows 侧 powershell.exe
# - DRY_RUN=true 透传为 -DryRun（环境变量同样继承，双保险）
# Windows 原生无 bash 时，请直接运行:
#   pwsh -ExecutionPolicy Bypass -File pwsh/install.ps1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/_common.sh"

if ! has_pwsh; then
  echo_warning "未找到 PowerShell（pwsh/powershell），跳过 PowerShell 模块"
  echo_detail "安装方式: winget install Microsoft.PowerShell（Windows）/ brew install powershell（macOS）"
  exit 0
fi

PWSH_BIN="$(select_pwsh_bin)"
if [[ -z "${PWSH_BIN}" ]]; then
  echo_warning "WSL 下未找到 Linux 原生 pwsh（已跳过 Windows 侧 powershell.exe），跳过"
  echo_detail "如需配置 Windows 侧 PowerShell，请在 Windows 终端中直接运行 install.ps1"
  exit 0
fi

pwsh_args=("$@")
if is_dry_run; then
  pwsh_args+=("-DryRun")
fi

echo_step "使用 PowerShell: ${PWSH_BIN}"
# -NoProfile: 安装器不加载用户 profile；-ExecutionPolicy Bypass: 仅本进程绕过 Windows 执行策略
"${PWSH_BIN}" -NoProfile -ExecutionPolicy Bypass -File "${SCRIPT_DIR}/install.ps1" "${pwsh_args[@]}"
