#!/usr/bin/env bash

# ======================
# PowerShell 模块体检器（bash 侧封装）
# ======================
#
# 供 Makefile doctor / CI 调度，实际检查逻辑在 check.ps1。
# - 优先调用 pwsh（PowerShell 7+），回退 powershell（Windows 自带 5.1）
# - WSL 下只接受 Linux 原生 pwsh，避免误用 Windows 侧 powershell.exe
# - 未安装 pwsh 时跳过（体检设计为 warn 不 fail，与 install.sh 的跳过行为一致）
# Windows 原生无 bash 时，请直接运行:
#   pwsh -NoProfile -ExecutionPolicy Bypass -File pwsh/check.ps1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/_common.sh"

if ! has_pwsh; then
  echo_skip "未安装 PowerShell（pwsh/powershell），跳过体检"
  echo_detail "安装方式: winget install Microsoft.PowerShell（Windows）/ brew install powershell（macOS）"
  exit 0
fi

PWSH_BIN="$(select_pwsh_bin)"
if [[ -z "${PWSH_BIN}" ]]; then
  echo_skip "WSL 下未找到 Linux 原生 pwsh（已跳过 Windows 侧 powershell.exe），跳过体检"
  exit 0
fi

echo_title "PowerShell 模块体检"
# -NoProfile: 体检的是配置文件本身，不叠加用户 profile 的干扰
"${PWSH_BIN}" -NoProfile -ExecutionPolicy Bypass -File "${SCRIPT_DIR}/check.ps1"
