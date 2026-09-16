#requires -Version 5.1
<#
.SYNOPSIS
  pwsh 模块公共函数库（PowerShell 原生）
.DESCRIPTION
  对应 bash 侧 lib/common.sh + lib/symlink.sh 的角色，供 install.ps1 / check.ps1
  以及 profile 运行时分片 dot-source。
  - 兼容 Windows PowerShell 5.1 与 PowerShell 7+（不使用 ??、?.、三元等 PS7 专有语法）
  - 所有输出图标使用 Unicode，本文件必须以 UTF-8 with BOM 保存（否则 PS5.1 按 GBK 解析会乱码）
.NOTES
  被 dot-source 时 $PSScriptRoot 为调用方脚本所在目录（pwsh/）
#>

# 防止重复 dot-source
if ($script:PwshCommonLoaded) { return }
$script:PwshCommonLoaded = $true

# ======================
# 1. 平台检测（PS 5.1 没有 $IsWindows / $IsLinux / $IsMacOS 自动变量）
# ======================

function Get-IsWindows {
    if ($PSVersionTable.PSEdition -eq 'Desktop') { return $true }
    if ($PSVersionTable.ContainsKey('Platform') -and $PSVersionTable.Platform -eq 'Win32NT') { return $true }
    if ($env:OS -eq 'Windows_NT') { return $true }
    return $false
}

function Get-PwshPlatform {
    if (Get-IsWindows) { return 'Windows' }
    # Unix 系：用 uname 区分（WSL 归入 Linux，另有 Test-Wsl 单独判断）
    $unameCmd = Get-Command uname -ErrorAction SilentlyContinue
    if ($null -ne $unameCmd) {
        $kernel = (& $unameCmd.Source -s) 2>$null
        if ($kernel -eq 'Darwin') { return 'macOS' }
        if ($kernel -eq 'Linux') { return 'Linux' }
    }
    return 'Unknown'
}

function Test-Wsl {
    # WSL1/WSL2 的 /proc/version 均包含 microsoft 字样
    $procVersion = '/proc/version'
    if (Test-Path -LiteralPath $procVersion) {
        $content = Get-Content -LiteralPath $procVersion -Raw -ErrorAction SilentlyContinue
        if ($null -ne $content -and $content -match 'microsoft|WSL') { return $true }
    }
    return $false
}

# ======================
# 2. 统一输出（Show-* 前缀避免覆盖内置 Write-Warning 等 cmdlet）
# ======================

$script:UseAnsiColor = $true
if ($null -ne $env:NO_COLOR -and $env:NO_COLOR -ne '') {
    $script:UseAnsiColor = $false
} else {
    # [Console]::IsOutputRedirected 在 .NET Framework 4.5（PS5.1）上不存在，探测失败则默认着色
    try {
        if ([Console]::IsOutputRedirected) { $script:UseAnsiColor = $false }
    } catch {
        $script:UseAnsiColor = $true
    }
}

function Format-Ansi {
    param(
        [Parameter(Mandatory = $true)][string]$Code,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text
    )
    if ($script:UseAnsiColor) {
        return ([char]27 + '[' + $Code + 'm' + $Text + [char]27 + '[0m')
    }
    return $Text
}

function Show-Step    { param([Parameter(Mandatory = $true)][string]$Message) Write-Host (Format-Ansi '1;36' (([char]0x279C).ToString() + '  ' + $Message)) }
function Show-Success { param([Parameter(Mandatory = $true)][string]$Message) Write-Host (Format-Ansi '32'   (([char]0x2713).ToString() + ' ' + $Message)) }
function Show-Warn    { param([Parameter(Mandatory = $true)][string]$Message) Write-Host (Format-Ansi '33'   (([char]0x26A0).ToString() + '  ' + $Message)) }
function Show-Error   { param([Parameter(Mandatory = $true)][string]$Message) Write-Host (Format-Ansi '31'   (([char]0x2717).ToString() + ' ' + $Message)) }
function Show-Skip    { param([Parameter(Mandatory = $true)][string]$Message) Write-Host (Format-Ansi '36'   (([char]0x2298).ToString() + ' ' + $Message)) }
function Show-Detail  { param([Parameter(Mandatory = $true)][string]$Message) Write-Host (Format-Ansi '34'   ('  ' + $Message)) }

function Show-Separator {
    Write-Host (Format-Ansi '34' ('=' * 44))
}

function Show-Header {
    param([Parameter(Mandatory = $true)][string]$Title)
    Show-Separator
    Write-Host (Format-Ansi '1;36' $Title)
    Show-Separator
}

# ======================
# 3. 通用工具
# ======================

function Test-Command {
    param([Parameter(Mandatory = $true)][string]$Name)
    # 守卫：Get-Command 在 Store 别名/函数劫持场景下可能返回异常，逐一验证 Source 存在
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($null -eq $cmd) { return $false }
    if ($cmd -is [array]) { $cmd = $cmd[0] }
    if ($null -ne $cmd.Source -and $cmd.Source -ne '' -and (Test-Path -LiteralPath $cmd.Source)) {
        return $true
    }
    # 函数/别名（无 Source 文件）也算可用
    if ($cmd.CommandType -eq 'Function' -or $cmd.CommandType -eq 'Alias') { return $true }
    return $false
}

function Test-DryRun {
    return ($null -ne $env:DRY_RUN -and $env:DRY_RUN -eq 'true')
}

function Get-DotfilesRoot {
    # 显式环境变量优先；否则以本文件位置（pwsh/_common.ps1）上溯一级
    if ($null -ne $env:DOTFILES_ROOT -and $env:DOTFILES_ROOT -ne '' -and
        (Test-Path -LiteralPath (Join-Path $env:DOTFILES_ROOT 'pwsh'))) {
        return $env:DOTFILES_ROOT
    }
    $here = $PSScriptRoot
    if ($null -eq $here -or $here -eq '') { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
    return (Split-Path -Parent $here)
}

# ======================
# 4. 安全符号链接（Windows 三层降级：SymbolicLink → Junction/HardLink → Copy）
# ======================

function Backup-Existing {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$BackupDir
    )
    if (-not (Test-Path -LiteralPath $BackupDir)) {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    }
    $safeName = ($Path -replace '[:\\/]', '_').TrimStart('_')
    $dest = Join-Path $BackupDir $safeName
    Copy-Item -LiteralPath $Path -Destination $dest -Recurse -Force
    Show-Detail ("已备份: " + $Path + " -> " + $dest)
}

function Resolve-FullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    try {
        return (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    } catch {
        # 路径尚不存在时按字符串规范化
        return [System.IO.Path]::GetFullPath($Path)
    }
}

function New-SafeLink {
    param(
        [Parameter(Mandatory = $true)][string]$Link,
        [Parameter(Mandatory = $true)][string]$Target,
        [string]$BackupDir
    )

    if (-not (Test-Path -LiteralPath $Target)) {
        Show-Error ("源文件不存在: " + $Target)
        return $false
    }
    $targetFull = Resolve-FullPath -Path $Target

    $existing = Get-Item -LiteralPath $Link -Force -ErrorAction SilentlyContinue
    if ($null -ne $existing) {
        # 已经是指向同一目标的链接 → 幂等跳过
        $current = $existing.Target
        if ($null -ne $current) {
            if ($current -is [array]) { $current = $current[0] }
            $currentFull = $null
            if (Test-Path -LiteralPath $current) { $currentFull = Resolve-FullPath -Path $current }
            if ($null -ne $currentFull -and $currentFull -eq $targetFull) {
                Show-Skip ("链接已存在: " + $Link)
                return $true
            }
        }

        if (Test-DryRun) {
            Show-Detail ("[dry-run] 将备份并替换: " + $Link + " -> " + $Target)
            return $true
        }

        # 指向别处的链接或普通文件/目录：先备份再替换
        if ($BackupDir) { Backup-Existing -Path $Link -BackupDir $BackupDir }
        Remove-Item -LiteralPath $Link -Force -Recurse -ErrorAction Stop
    } else {
        if (Test-DryRun) {
            Show-Detail ("[dry-run] 将创建链接: " + $Link + " -> " + $Target)
            return $true
        }
    }

    # 确保父目录存在（如 Windows 下 Documents\PowerShell 首次安装时不存在）
    $parent = Split-Path -Parent $Link
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $targetIsDir = (Get-Item -LiteralPath $Target -Force).PSIsContainer

    if (Get-IsWindows) {
        # 第 1 层：真正的符号链接（需管理员权限或开启开发者模式）
        try {
            New-Item -ItemType SymbolicLink -Path $Link -Target $Target -ErrorAction Stop | Out-Null
            return $true
        } catch {
            Show-Warn "符号链接创建失败（需要管理员权限或开发者模式），尝试降级方案..."
        }

        # 第 2 层：目录用 Junction（不需要提权），文件用 HardLink（同卷限制）
        try {
            if ($targetIsDir) {
                New-Item -ItemType Junction -Path $Link -Target $Target -ErrorAction Stop | Out-Null
                Show-Warn ("已用 Junction（目录连接）替代符号链接: " + $Link)
            } else {
                New-Item -ItemType HardLink -Path $Link -Target $Target -ErrorAction Stop | Out-Null
                Show-Warn ("已用 HardLink（硬链接）替代符号链接: " + $Link + "（不随源文件独立更新，且不可跨卷）")
            }
            return $true
        } catch {
            Show-Warn "Junction/HardLink 也失败，降级为普通复制..."
        }

        # 第 3 层：复制（最终兜底，保证配置可用）
        if ($targetIsDir) {
            Copy-Item -LiteralPath $Target -Destination $Link -Recurse -Force
        } else {
            Copy-Item -LiteralPath $Target -Destination $Link -Force
        }
        Show-Warn ("已复制内容替代链接（建议开启 Windows 开发者模式后重新安装以使用真正的符号链接）: " + $Link)
        return $true
    }

    # Linux / macOS：符号链接无特权要求
    New-Item -ItemType SymbolicLink -Path $Link -Target $Target -ErrorAction Stop | Out-Null
    return $true
}
