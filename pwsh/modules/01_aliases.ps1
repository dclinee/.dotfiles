﻿#requires -Version 5.1
<# 别名与跨 shell 一致的快捷函数（zsh 侧同名，降低切换成本） #>

# PowerShell 的 Set-Alias 只能映射命令名、不能附带参数，因此带参数的一律用 function + @args 透传。

# ---------- Git 快捷函数（gitconfig 内的 git 别名对所有 shell 通用，此处只补充交互式高频写法） ----------
function g   { git @args }
function ga  { git add @args }
function gd  { git diff @args }
function gdc { git diff --cached @args }
function gst { git status -sb @args }
function gl  { git pull @args }
function gp  { git push @args }
function gc  { git commit @args }
function gca { git commit --amend --no-edit @args }
function gco { git checkout @args }
function gb  { git branch @args }
function glog { git lg @args }

# ---------- 文件列表：eza 优先，缺失时回退 Get-ChildItem ----------
function ll {
    if (Test-Command eza) {
        eza -l --git --group-directories-first @args
    } else {
        Get-ChildItem @args | Format-Table -AutoSize
    }
}
function la {
    if (Test-Command eza) {
        eza -la --git --group-directories-first @args
    } else {
        Get-ChildItem -Force @args | Format-Table -AutoSize
    }
}
function lt {
    if (Test-Command eza) {
        eza -T --level=2 @args
    } else {
        Get-ChildItem -Recurse -Depth 1 @args | Format-Table -AutoSize
    }
}

# ---------- 跨平台常用小工具 ----------

# which：PS 在 Windows 上没有此命令（Get-Command 的 Source 可能是别名 stub，做存在性守卫）
function which {
    param([Parameter(Mandatory = $true)][string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($null -eq $cmd) {
        Write-Host ("未找到命令: " + $Name)
        return
    }
    if ($cmd -is [array]) { $cmd = $cmd[0] }
    if ($cmd.Source) { $cmd.Source } else { $cmd.Name }
}

# touch：更新时间戳或创建空文件（Windows 原生无 touch）
function touch {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (Test-Path -LiteralPath $Path) {
        (Get-Item -LiteralPath $Path).LastWriteTime = Get-Date
    } else {
        New-Item -ItemType File -Path $Path | Out-Null
    }
}

# mkcd：创建目录并进入
function mkcd {
    param([Parameter(Mandatory = $true)][string]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Set-Location -LiteralPath $Path
}

# Reload-Profile：改完配置免重启加载
function Reload-Profile {
    . $PROFILE.CurrentUserCurrentHost
    Show-Success "PowerShell Profile 已重新加载"
}
