#!/usr/bin/env bash
# pwsh/_common.sh
# PowerShell 模块的 bash 侧公共函数（install.sh 经 bootstrap.sh 调用时使用）
source "$(dirname "${BASH_SOURCE[0]}")/../lib/_module_loader.sh" "PWSH_DIR"

# 粗检：pwsh（PowerShell 7+）优先，powershell（Windows 5.1）兜底
has_pwsh() { has_cmd pwsh || has_cmd powershell; }
has_pwsh || return 0

# 选择实际要调用的解释器路径
# WSL 下排除 Windows 互操作的 *.exe（那是 Windows 侧运行时，链接的是 Windows 路径的 Profile，
# 在 WSL 中应当只使用 Linux 原生 pwsh）
select_pwsh_bin() {
  if grep -qi microsoft /proc/version 2>/dev/null; then
    command -v pwsh 2>/dev/null | grep -v '\.exe$' | head -n 1 || true
    return 0
  fi
  command -v pwsh 2>/dev/null || command -v powershell 2>/dev/null || true
}


