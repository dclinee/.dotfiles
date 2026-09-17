#requires -Version 5.1
<#
.SYNOPSIS
  PowerShell Profile 主入口（被链接到 $PROFILE.CurrentUserCurrentHost）
.DESCRIPTION
  按顺序 dot-source modules/ 下的分片，单片加载失败不阻断整体启动；
  modules/99_local.ps1 为本地覆盖文件（不入库），与 zsh 的 .zshrc.local 对齐。
#>

$ErrorActionPreference = 'Continue'

# ======================
# 定位真实的 pwsh 模块目录
# ======================
# profile.ps1 落地到 $PROFILE 的方式不同，$PSScriptRoot 的可信度也不同：
#   1. SymbolicLink（推荐）：自身目录无 _common.ps1，需解析链接 .Target
#   2. HardLink / Copy 兜底（Windows 跨卷或无开发者模式）：伴生内容由安装器同步到
#      自身目录；若伴生缺失（如旧版本安装的单文件副本），继续向后回退
#   3. $env:DOTFILES_ROOT\pwsh
#   4. $HOME\.dotfiles\pwsh（跨盘符也能找到仓库，如仓库在 C 盘、Documents 在 D 盘）
$profileCandidates = [System.Collections.Generic.List[string]]::new()

$selfDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($selfDir)) {
    $selfDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
if ($selfDir) { [void]$profileCandidates.Add($selfDir) }

# 符号链接 Target 解析（Target 一般是安装时写入的绝对路径；相对路径则相对链接自身所在目录）
$selfPath = $MyInvocation.MyCommand.Path
if (-not $selfPath) { $selfPath = $PROFILE.CurrentUserCurrentHost }
$selfItem = Get-Item -LiteralPath $selfPath -Force -ErrorAction SilentlyContinue
if ($null -ne $selfItem -and $selfItem.Target) {
    $linkTarget = @($selfItem.Target)[0]
    if (-not [System.IO.Path]::IsPathRooted($linkTarget)) {
        $linkTarget = Join-Path (Split-Path -Parent $selfPath) $linkTarget
    }
    [void]$profileCandidates.Add((Split-Path -Parent $linkTarget))
}

# 环境变量与标准仓库位置（覆盖 HardLink/Copy 伴生缺失的场景）
if ($env:DOTFILES_ROOT) {
    [void]$profileCandidates.Add((Join-Path $env:DOTFILES_ROOT 'pwsh'))
}
if ($HOME) {
    [void]$profileCandidates.Add((Join-Path (Join-Path $HOME '.dotfiles') 'pwsh'))
}

$PwshProfileDir = $null
foreach ($candidate in $profileCandidates) {
    if ($candidate -and (Test-Path -LiteralPath (Join-Path $candidate '_common.ps1'))) {
        $PwshProfileDir = $candidate
        break
    }
}

if ([string]::IsNullOrEmpty($PwshProfileDir)) {
    Write-Warning '[dotfiles] 找不到 _common.ps1：profile 可能是未同步伴生内容的旧副本，请重新运行 pwsh/install.ps1'
    return
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
