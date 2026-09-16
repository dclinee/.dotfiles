#requires -Version 5.1
<#
.SYNOPSIS
  PowerShell Profile 主入口（被链接到 $PROFILE.CurrentUserCurrentHost）
.DESCRIPTION
  按顺序 dot-source modules/ 下的分片，单片加载失败不阻断整体启动；
  modules/99_local.ps1 为本地覆盖文件（不入库），与 zsh 的 .zshrc.local 对齐。
#>

$ErrorActionPreference = 'Continue'

# $PSScriptRoot 在「通过符号链接加载」时指向链接所在目录（如 ~/.config/powershell），
# 而不是仓库内的真实 pwsh/ 目录，需要沿 reparse point 解析到真实目标。
$PwshProfileDir = $PSScriptRoot
if ($null -eq $PwshProfileDir -or $PwshProfileDir -eq '') {
    $PwshProfileDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
if (-not (Test-Path -LiteralPath (Join-Path $PwshProfileDir '_common.ps1'))) {
    $selfPath = $MyInvocation.MyCommand.Path
    if (-not $selfPath) { $selfPath = $PROFILE.CurrentUserCurrentHost }
    $linkItem = Get-Item -LiteralPath $selfPath -Force -ErrorAction SilentlyContinue
    if ($null -ne $linkItem -and $linkItem.Target) {
        $realSelf = @($linkItem.Target)[0]
        # Target 一般是安装时写入的绝对路径；相对路径则相对链接所在目录解析
        if (-not [System.IO.Path]::IsPathRooted($realSelf)) {
            $realSelf = Join-Path (Split-Path -Parent $selfPath) $realSelf
        }
        if (Test-Path -LiteralPath $realSelf) {
            $PwshProfileDir = Split-Path -Parent $realSelf
        }
    }
}

# 公共函数库（平台检测 / Show-* / Test-Command 等，交互会话中也可直接使用）
. (Join-Path $PwshProfileDir '_common.ps1')

# 分片加载顺序：环境 → 别名 → 函数 → 提示符
$profileParts = @('00_env', '01_aliases', '02_functions', '03_prompt')
foreach ($part in $profileParts) {
    $partPath = Join-Path $PwshProfileDir ('modules' + [System.IO.Path]::DirectorySeparatorChar + $part + '.ps1')
    try {
        . $partPath
    } catch {
        Write-Warning ("[dotfiles] 加载 " + $part + ".ps1 失败: " + $_.Exception.Message)
    }
}

# 本地覆盖（可选，不纳入 git）
$localOverride = Join-Path $PwshProfileDir 'modules/99_local.ps1'
if (Test-Path -LiteralPath $localOverride) {
    . $localOverride
}
