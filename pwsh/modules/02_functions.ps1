#requires -Version 5.1
<# 交互式辅助函数（环境体检、Git 信息探测等） #>

# 检测当前是否为管理员会话（Windows：Administrator 角色；Unix：uid 0）
function Test-Administrator {
    if (Get-IsWindows) {
        try {
            $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
            $principal = New-Object Security.Principal.WindowsPrincipal($identity)
            return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        } catch {
            return $false
        }
    }
    return ((id -u) 2>$null) -eq '0'
}

# 获取当前目录的 Git 分支名（非 Git 目录返回 $null），供 prompt 使用
function Get-GitBranch {
    if (-not (Test-Command git)) { return $null }
    $branch = $null
    try {
        $branch = (& git symbolic-ref --quiet --short HEAD 2>$null)
        if (-not $branch) {
            # detached HEAD：显示短 SHA
            $branch = (& git rev-parse --short HEAD 2>$null)
        }
    } catch {
        return $null
    }
    return $branch
}

# 当前 Git 工作区是否有未提交改动（prompt 颜色用）
function Test-GitDirty {
    if (-not (Test-Command git)) { return $false }
    try {
        $status = (& git status --porcelain 2>$null)
        return ($null -ne $status -and "$status".Trim() -ne '')
    } catch {
        return $false
    }
}

<#
.SYNOPSIS
  单次 git status 聚合 prompt 所需的全部 Git 信息（避免每个片段各调一次 git）
.OUTPUTS
  非 Git 目录返回 $null；否则返回 Hashtable：
  Branch / Ahead / Behind / Staged / Unstaged / Untracked / Conflicted
#>
function Get-GitPromptInfo {
    if (-not (Test-Command git)) { return $null }
    $lines = @(& git status --porcelain=v1 --branch --untracked-files=normal 2>$null)
    if (-not $lines -or $lines.Count -eq 0) { return $null }

    $info = @{
        Branch     = $null
        Ahead      = 0
        Behind     = 0
        Staged     = 0
        Unstaged   = 0
        Untracked  = 0
        Conflicted = 0
    }

    foreach ($line in $lines) {
        if ($line.Length -eq 0) { continue }
        if ($line.StartsWith('## ')) {
            $head = $line.Substring(3)
            # 解析 ahead/behind 计数
            if ($head -match 'ahead (\d+)') { $info.Ahead = [int]$Matches[1] }
            if ($head -match 'behind (\d+)') { $info.Behind = [int]$Matches[1] }
            # 分支名：'main...origin/main' / 'main' / 'HEAD (no branch)'（分离头指针）
            if ($head -like 'HEAD *') {
                $info.Branch = (& git rev-parse --short HEAD 2>$null)
            } else {
                $namePart = ($head -split '\.\.')[0].Trim()
                $namePart = $namePart -replace '^No commits yet on ', ''
                $info.Branch = $namePart
            }
            continue
        }

        # XY 状态码（porcelain 每行前两列）
        $x = $line.Substring(0, 1)
        $y = $line.Substring(1, 1)
        if ($x -eq '?' -and $y -eq '?') {
            $info.Untracked++
        } elseif ($x -eq 'U' -or $y -eq 'U' -or ($x -eq 'A' -and $y -eq 'A') -or
                  ($x -eq 'D' -and $y -eq 'D')) {
            $info.Conflicted++
        } else {
            if ($x -ne ' ' -and $x -ne '?') { $info.Staged++ }
            if ($y -ne ' ' -and $y -ne '?') { $info.Unstaged++ }
        }
    }

    if (-not $info.Branch) { return $null }
    return $info
}

<#
.SYNOPSIS
  PowerShell + dotfiles 交互式环境体检（对应 bash 侧的 check_env）
#>
function Invoke-EnvironmentCheck {
    Show-Header "PowerShell 环境体检"

    # PowerShell 版本
    $psVersion = $PSVersionTable.PSVersion.ToString()
    if ($PSVersionTable.PSEdition -eq 'Core') {
        Show-Success ("PowerShell " + $psVersion + " (Core)")
    } else {
        Show-Warn ("Windows PowerShell " + $psVersion + " (5.1 已停止维护，建议安装 PowerShell 7: winget install Microsoft.PowerShell)")
    }

    # 平台
    Show-Success ("平台: " + (Get-PwshPlatform) + $(if (Test-Wsl) { ' (WSL)' } else { '' }))

    # Profile 链接状态
    $profilePath = $PROFILE.CurrentUserCurrentHost
    if (Test-Path -LiteralPath $profilePath) {
        $item = Get-Item -LiteralPath $profilePath -Force
        if ($item.LinkType -eq 'SymbolicLink' -or $item.LinkType -eq 'Junction') {
            Show-Success ("Profile 已链接: " + $item.Target)
        } else {
            Show-Warn ("Profile 是普通文件而非链接: " + $profilePath)
        }
    } else {
        Show-Error ("Profile 不存在: " + $profilePath + "（请运行 pwsh/install.ps1）")
    }

    # 关键工具
    $tools = @('git', 'starship', 'zoxide', 'eza', 'rg', 'fzf')
    foreach ($tool in $tools) {
        if (Test-Command $tool) {
            Show-Success ("已安装: " + $tool)
        } else {
            Show-Skip ("未安装（可选）: " + $tool)
        }
    }

    # Windows 链接能力提示
    if (Get-IsWindows) {
        try {
            $probe = Join-Path $env:TEMP ('pwsh_link_probe_' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType SymbolicLink -Path $probe -Target $env:TEMP -ErrorAction Stop | Out-Null
            Remove-Item -LiteralPath $probe -Force
            Show-Success "符号链接权限: 可用（开发者模式或管理员）"
        } catch {
            Show-Warn "符号链接权限: 不可用，安装时将降级为 Junction/HardLink/复制（建议开启开发者模式）"
        }
    }

    Show-Separator
}
Set-Alias -Name check_ps -Value Invoke-EnvironmentCheck -Scope Global
