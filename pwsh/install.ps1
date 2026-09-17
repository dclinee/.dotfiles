#requires -Version 5.1
<#
.SYNOPSIS
  pwsh 模块主安装器（跨平台：Windows 原生 / Linux / macOS）
.DESCRIPTION
  1. 将 $PROFILE.CurrentUserCurrentHost 链接到仓库内 pwsh/profile.ps1
  2. 默认同时链接 Git 三件套并创建 .gitconfig.local 模板（-SkipGit 可跳过）
  Windows 原生没有 bash，本脚本是该平台的独立入口，无需 bootstrap.sh。
.PARAMETER DryRun
  预演模式：软链/备份/模板创建只打印不落地（也可通过环境变量 DRY_RUN=true 开启，
  以便 bash 侧 bootstrap.sh --dry-run 透传）
.PARAMETER SkipGit
  仅安装 PowerShell Profile，不处理 Git 配置
.EXAMPLE
  pwsh -ExecutionPolicy Bypass -File install.ps1
.EXAMPLE
  pwsh -ExecutionPolicy Bypass -File install.ps1 -DryRun
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$SkipGit
)

$ErrorActionPreference = 'Stop'

# 兼容 bash 侧透传的 DRY_RUN=true 环境变量
if ($DryRun) { $env:DRY_RUN = 'true' }

# ---------- 定位路径 ----------
$PwshDir = $PSScriptRoot
if ($null -eq $PwshDir -or $PwshDir -eq '') {
    $PwshDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
. (Join-Path $PwshDir '_common.ps1')

$DotfilesRoot = Get-DotfilesRoot
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$BackupDir = Join-Path $HOME ('.cache' + [System.IO.Path]::DirectorySeparatorChar +
                              'dotfiles_pwsh_backup_' + $stamp)

# ---------- 安装流程 ----------
Show-Header "PowerShell 配置安装器"
if ($PSVersionTable.PSEdition -eq 'Core') {
    Show-Detail ("PowerShell " + $PSVersionTable.PSVersion + " (Core) / 平台: " + (Get-PwshPlatform))
} else {
    Show-Detail ("Windows PowerShell " + $PSVersionTable.PSVersion + " (Desktop)")
}
if (Test-DryRun) {
    Show-Warn "DRY-RUN 预演模式：软链创建/备份/模板写入只打印，不实际修改配置文件"
}
Show-Detail ("Dotfiles 根目录: " + $DotfilesRoot)

$failures = 0

# ---------- 1. PowerShell Profile ----------
Show-Step "链接 PowerShell Profile..."
$profileSource = Join-Path $PwshDir 'profile.ps1'
$profileTarget = $PROFILE.CurrentUserCurrentHost
# profile.ps1 依赖同目录的 _common.ps1 与 modules/，HardLink/Copy 兜底时必须同步伴生内容
if (New-SafeLink -Link $profileTarget -Target $profileSource -BackupDir $BackupDir `
                 -CompanionPaths @('_common.ps1', 'modules')) {
    Show-Success ("Profile 已链接: " + $profileTarget)
} else {
    Show-Error "Profile 链接失败"
    $failures++
}

# ---------- 2. Git 配置（Windows 原生场景的刚需：无 bash 可跑 git/install.sh） ----------
if (-not $SkipGit) {
    Show-Step "链接 Git 配置..."

    if (-not (Test-Command git)) {
        Show-Warn "未检测到 git，跳过 Git 配置（安装 Git for Windows 后重新运行本脚本）"
    } else {
        $gitDir = Join-Path $DotfilesRoot 'git'
        $gitLinks = @(
            @{ Src = '.gitconfig';       Dst = '.gitconfig' },
            @{ Src = '.gitignore_global'; Dst = '.gitignore_global' },
            @{ Src = '.gitattributes';    Dst = '.gitattributes' }
        )
        foreach ($pair in $gitLinks) {
            $src = Join-Path $gitDir $pair.Src
            $dst = Join-Path $HOME $pair.Dst
            if (New-SafeLink -Link $dst -Target $src -BackupDir $BackupDir) {
                Show-Success ("已链接: " + $dst)
            } else {
                Show-Error ("链接失败: " + $dst)
                $failures++
            }
        }

        # .gitconfig.local 模板（个人信息不入库；与 git/install.sh 的模板保持一致）
        $localConfig = Join-Path $HOME '.gitconfig.local'
        if (Test-Path -LiteralPath $localConfig) {
            Show-Success ".gitconfig.local 已存在"
        } else {
            $template = @'
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
'@
            if (Test-DryRun) {
                Show-Detail ("[dry-run] 将创建模板: " + $localConfig)
            } else {
                # UTF-8 无 BOM（git 读取配置文件不需要 BOM）
                [System.IO.File]::WriteAllText($localConfig, $template, (New-Object System.Text.UTF8Encoding($false)))
                Show-Warn "已创建 ~/.gitconfig.local 模板，请修改其中的用户信息"
            }
        }

        # Windows：仓库主 gitconfig 的 credential.helper=cache 在 Git for Windows 不可用，
        # 将平台专用 helper 写入 .gitconfig.local（include 覆盖），不改动被链接的仓库文件
        if (Get-IsWindows) {
            $currentHelper = $null
            $currentHelper = git config --global credential.helper 2>$null
            if (-not $currentHelper) {
                $helperName = 'manager'
                if (Test-DryRun) {
                    Show-Detail ("[dry-run] 将在 .gitconfig.local 设置 credential.helper=" + $helperName)
                } else {
                    git config --file "$localConfig" credential.helper $helperName 2>$null
                    $verify = git config --global credential.helper 2>$null
                    if (-not $verify) {
                        # 旧版 Git for Windows（2.38 之前）helper 名为 manager-core
                        git config --file "$localConfig" --unset credential.helper 2>$null
                        git config --file "$localConfig" credential.helper manager-core 2>$null
                    }
                    Show-Success ("Windows 凭证助手已配置到 .gitconfig.local: " + (git config --global credential.helper 2>$null))
                }
            } else {
                Show-Success ("credential.helper 已配置: " + $currentHelper)
            }
        }

        # 用户信息占位符检查
        $userName = $null
        $userName = git config user.name 2>$null
        if (-not $userName -or $userName -eq 'YOUR_NAME' -or $userName -eq 'Your Name') {
            Show-Warn "Git 用户信息未配置，请编辑 ~/.gitconfig.local"
        }
    }
}

# ---------- 汇总 ----------
Show-Separator
if ($failures -gt 0) {
    Show-Error ("安装完成，但有 " + $failures + " 项失败，请检查上方输出")
    exit 1
}
Show-Success "PowerShell 配置安装成功！"
if (Get-IsWindows) {
    Write-Host ""
    Write-Host "下一步:"
    Write-Host "  1. 重启 PowerShell / Windows Terminal，或执行: . `$PROFILE"
    Write-Host "  2. 运行 check_ps 检查环境"
    Write-Host "  3. 如提示链接降级，可在 设置 → 开发者选项 中开启「开发者模式」后重新安装"
} else {
    Write-Host ""
    Write-Host "下一步: 重启 pwsh 或执行 . `$PROFILE，然后运行 check_ps"
}
