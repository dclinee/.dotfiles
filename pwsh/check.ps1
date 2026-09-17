#requires -Version 5.1
<#
.SYNOPSIS
  pwsh 模块体检脚本（PowerShell 原生）
.DESCRIPTION
  镜像 bash 侧 check.sh 的 check_ok/check_warn/check_fail/check_summary 模式：
  - PASS: 符合预期
  - WARN: 不阻断使用（如未安装、PSReadLine 缺失）
  - FAIL: 需要修复（如链接指向错误、模块文件缺失）
  退出码: FAIL > 0 → 1，否则 0
  运行环境: 通常由 check.sh 以 -NoProfile 调用；Windows 原生也可直接运行:
    pwsh -NoProfile -ExecutionPolicy Bypass -File pwsh/check.ps1
.NOTES
  本文件必须以 UTF-8 with BOM 保存（PS5.1 无 BOM 时按 GBK 解析会乱码）
#>

[CmdletBinding()]
param()

# 公共函数库（Show-* 输出 / Test-Command / Get-DotfilesRoot 等）
. (Join-Path $PSScriptRoot '_common.ps1')

# ======================
# 体检计数器（镜像 bash 侧 check_init）
# ======================
$script:CheckPass = 0
$script:CheckWarn = 0
$script:CheckFail = 0
$script:CheckSkip = 0

function Check-Ok   { param([Parameter(Mandatory = $true)][string]$Message) Show-Success $Message; $script:CheckPass++ }
function Check-Warn { param([Parameter(Mandatory = $true)][string]$Message) Show-Warn    $Message; $script:CheckWarn++ }
function Check-Fail { param([Parameter(Mandatory = $true)][string]$Message) Show-Error   $Message; $script:CheckFail++ }
function Check-Skip { param([Parameter(Mandatory = $true)][string]$Message) Show-Skip    $Message; $script:CheckSkip++ }

Show-Header 'PowerShell 模块体检'

# ---------- 1. 运行时环境 ----------
$psVersion = $PSVersionTable.PSVersion.ToString()
$editionLabel = 'Unknown'
if ($PSVersionTable.ContainsKey('PSEdition')) { $editionLabel = $PSVersionTable['PSEdition'] }
Check-Ok ("PowerShell " + $psVersion + " (" + $editionLabel + " Edition)")

$platformDetail = Get-PwshPlatform
if (Test-Wsl) { $platformDetail = $platformDetail + ' (WSL)' }
Show-Detail ('平台: ' + $platformDetail)

# ---------- 2. 仓库文件完整性 ----------
$requiredFiles = @(
    'profile.ps1',
    '_common.ps1',
    'install.ps1',
    'install.sh',
    'check.ps1',
    'check.sh',
    (Join-Path 'modules' '00_env.ps1'),
    (Join-Path 'modules' '01_aliases.ps1'),
    (Join-Path 'modules' '02_functions.ps1'),
    (Join-Path 'modules' '03_prompt.ps1')
)
foreach ($rel in $requiredFiles) {
    $full = Join-Path $PSScriptRoot $rel
    if (Test-Path -LiteralPath $full) {
        Check-Ok ("文件存在: " + $rel)
    } else {
        Check-Fail ("文件缺失: " + $rel)
    }
}

# DOTFILES_ROOT 反推（_common.ps1 按自身位置上溯一级）
$dotfilesRoot = Get-DotfilesRoot
if (Test-Path -LiteralPath (Join-Path $dotfilesRoot 'pwsh')) {
    Check-Ok ("DOTFILES_ROOT 解析正常: " + $dotfilesRoot)
} else {
    Check-Fail ("DOTFILES_ROOT 解析异常: " + $dotfilesRoot)
}

# ---------- 3. Profile 链接状态 + 加载冒烟测试 ----------
# 原理: profile 加载 _common.ps1 后会定义 Show-Step 等函数，
#       子进程 exit 0 即代表 profile 完整加载且函数可用
$profilePath   = $PROFILE.CurrentUserCurrentHost
$profileSource = Join-Path $PSScriptRoot 'profile.ps1'
$profileInstalled = $false

if ([string]::IsNullOrEmpty($profilePath)) {
    Check-Warn '无法获取 $PROFILE 路径（当前宿主不支持）'
} elseif (-not (Test-Path -LiteralPath $profilePath)) {
    Check-Warn ("Profile 未安装: " + $profilePath)
    Show-Detail '运行 install.ps1 可安装'
} else {
    $profileInstalled = $true
    $profileItem = Get-Item -LiteralPath $profilePath -Force
    $linkTarget = $profileItem.Target
    if ($linkTarget -is [array]) { $linkTarget = $linkTarget[0] }

    if ([string]::IsNullOrEmpty($linkTarget)) {
        Check-Warn ("Profile 是普通文件而非链接: " + $profilePath)
        Show-Detail '重新运行 install.ps1 可替换为链接'
    } else {
        # 相对 Target 相对链接所在目录解析（与 profile.ps1 运行时逻辑一致）
        if (-not [System.IO.Path]::IsPathRooted($linkTarget)) {
            $linkTarget = Join-Path (Split-Path -Parent $profilePath) $linkTarget
        }
        $expectedFull = Resolve-FullPath -Path $profileSource
        $currentFull  = $linkTarget
        if (Test-Path -LiteralPath $linkTarget) {
            try { $currentFull = (Resolve-Path -LiteralPath $linkTarget -ErrorAction Stop).Path } catch { }
        }
        # Windows 路径大小写不敏感
        $pointsToSource = ($currentFull -eq $expectedFull) -or
                          ((Get-IsWindows) -and ($currentFull -ieq $expectedFull))
        if ($pointsToSource) {
            Check-Ok ("Profile 链接指向正确: " + $profilePath)
        } else {
            Check-Fail ("Profile 链接指向错误: " + $profilePath + " -> " + $linkTarget)
            Show-Detail ("预期指向: " + $profileSource)
        }
    }
}

# ---------- 4. PSReadLine（命令行编辑体验，缺失不阻断） ----------
$psrlModule = Get-Module -ListAvailable -Name PSReadLine | Select-Object -First 1
if ($null -ne $psrlModule) {
    Check-Ok ("PSReadLine " + $psrlModule.Version)
} else {
    Check-Warn '未找到 PSReadLine（命令行编辑功能受限）'
}

# ---------- 5. Profile 加载冒烟测试（子进程，非交互；未安装时跳过） ----------
$currentBin = $null
try { $currentBin = (Get-Process -Id $PID).Path } catch { }
if (-not $profileInstalled) {
    Check-Skip 'Profile 未安装，跳过加载冒烟测试'
} elseif ([string]::IsNullOrEmpty($currentBin)) {
    Check-Skip '无法确定当前解释器路径，跳过 Profile 冒烟测试'
} else {
    Show-Step 'Profile 加载冒烟测试（子进程）...'
    # 除函数定义外，实际调用 prompt 一次（返回非空且不抛异常），捕获 prompt 主题自身的运行时错误（如路径/ANSI 处理回归）
    $smokeCmd = 'try { if ((Get-Command Show-Step -ErrorAction SilentlyContinue) -and (prompt)) { exit 0 } else { exit 3 } } catch { exit 4 }'
    & $currentBin -NoLogo -NonInteractive -Command $smokeCmd | Out-Null
    $smokeRc = $LASTEXITCODE
    if ($smokeRc -eq 0) {
        Check-Ok 'Profile 加载正常（Show-Step 已定义，prompt 渲染无异常）'
    } else {
        Check-Fail ('Profile 加载异常（退出码 ' + $smokeRc + '）')
        Show-Detail '请手动运行 pwsh -NoLogo -Command "exit" 查看加载报错'
    }
}

# ---------- 汇总（镜像 bash 侧 check_summary） ----------
Show-Header '体检结果'
$summaryLine = ([string][char]0x2713) + ' 通过: ' + $script:CheckPass + '  ' +
               ([string][char]0x26A0) + '  警告: ' + $script:CheckWarn + '  ' +
               ([string][char]0x2717) + ' 失败: ' + $script:CheckFail + '  ' +
               ([string][char]0x2298) + ' 跳过: ' + $script:CheckSkip
Write-Host (Format-Ansi '0' $summaryLine)

if ($script:CheckFail -gt 0) {
    Show-Error ("存在 " + $script:CheckFail + " 项失败，建议修复")
    exit 1
} elseif ($script:CheckWarn -gt 0) {
    Show-Warn ("存在 " + $script:CheckWarn + " 项警告，建议检查")
} else {
    Show-Success '全部体检通过'
}
exit 0
