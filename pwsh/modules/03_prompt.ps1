#requires -Version 5.1
<#
.SYNOPSIS
  提示符主题：双行、ANSI-256 色、不依赖 Nerd Font（Cascadia/Consolas 可渲染）
.DESCRIPTION
  第一行：失败标记 | 虚拟环境 | 智能缩短路径 | Git(分支/ahead/behind/改动计数) | 任务数 | 耗时
  第二行：❯（成功绿/失败红，管理员加 ⚡）
  无 ANSI（重定向/老终端）时自动降级为纯文本；starship 存在则由 starship 覆盖。
  可用 $env:DOTFILES_PROMPT_COMPACT = '1' 关闭命令间空行。
#>

# ---------- zoxide（若安装）：提供 z/zi 智能跳转 ----------
if (Test-Command zoxide) {
    try {
        Invoke-Expression ((zoxide init powershell | Out-String))
    } catch {
        # 初始化失败静默忽略，不影响 prompt
    }
}

# 智能缩短路径：$HOME 缩写为 ~；超过 3 层时中间目录只保留首字母
function Format-PromptPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ($null -ne $HOME -and $Path.StartsWith($HOME, [System.StringComparison]::OrdinalIgnoreCase)) {
        $Path = '~' + $Path.Substring($HOME.Length)
    }

    $sep = [System.IO.Path]::DirectorySeparatorChar
    $altSep = [System.IO.Path]::AltDirectorySeparatorChar
    $isAbsolute = $Path.StartsWith($sep) -or ($Path -match '^[A-Za-z]:[\/]')
    $parts = $Path.Split([char[]]@($sep, $altSep)) | Where-Object { $_ -ne '' }
    if ($parts.Count -le 3) { return $Path }

    # 末两段保留全名，其余只留首字母（盘符 C: 原样保留）
    $collapsed = [System.Collections.Generic.List[string]]::new()
    for ($i = 0; $i -lt ($parts.Count - 2); $i++) {
        $p = $parts[$i]
        if ($p -match '^[A-Za-z]:$') {
            [void]$collapsed.Add($p)
        } else {
            [void]$collapsed.Add($p.Substring(0, 1))
        }
    }
    [void]$collapsed.Add($parts[$parts.Count - 2])
    [void]$collapsed.Add($parts[$parts.Count - 1])
    $result = $collapsed -join $sep
    # Unix 绝对路径补回根分隔符（Windows 盘符 C: 已包含在首段）
    if ($isAbsolute -and -not ($result -match '^[A-Za-z]:') -and -not $result.StartsWith('~')) {
        $result = $sep + $result
    }
    return $result
}

# 耗时人类可读：300ms 以下不显示
function Format-PromptDuration {
    param([TimeSpan]$Elapsed)
    if ($Elapsed.TotalMilliseconds -lt 300) { return '' }
    if ($Elapsed.TotalSeconds -lt 60) {
        return ('{0:N1}s' -f $Elapsed.TotalSeconds)
    }
    return ('{0}m{1:d2}s' -f [int]$Elapsed.TotalMinutes, $Elapsed.Seconds)
}

function global:prompt {
    # 必须在任何原生命令（含 git）之前捕获退出码
    $exitCode = $LASTEXITCODE
    $failed = ($null -ne $exitCode -and $exitCode -ne 0)

    $e = [char]27
    if ($script:UseAnsiColor) {
        $cReset = "$e[0m"
        $cDim   = "$e[38;5;244m"
        $cPath  = "$e[1;38;5;45m"
        $cGitOk = "$e[38;5;114m"
        $cGitChg= "$e[38;5;221m"
        $cGitBad= "$e[1;38;5;203m"
        $cVenv  = "$e[38;5;215m"
        $cNum   = "$e[38;5;245m"
        $cOk    = "$e[1;38;5;114m"
        $cErr   = "$e[1;38;5;203m"
        $cAdmin = "$e[1;38;5;221m"
    } else {
        $cReset = $cDim = $cPath = $cGitOk = $cGitChg = $cGitBad = ''
        $cVenv = $cNum = $cOk = $cErr = $cAdmin = ''
    }

    # ---------- 片段 1：失败退出码 ----------
    $errPart = ''
    if ($failed) { $errPart = $cErr + [char]0x2717 + ' ' + $exitCode + ' ' }

    # ---------- 片段 2：Python venv / conda ----------
    $venvPart = ''
    $venvName = $null
    if ($env:VIRTUAL_ENV) {
        $venvName = Split-Path -Leaf $env:VIRTUAL_ENV
    } elseif ($env:CONDA_DEFAULT_ENV -and $env:CONDA_DEFAULT_ENV -ne 'base') {
        $venvName = $env:CONDA_DEFAULT_ENV
    }
    if ($venvName) { $venvPart = $cVenv + '(' + $venvName + ') ' }

    # ---------- 片段 3：路径 ----------
    $rawPath = $PWD.Path
    $shortPath = Format-PromptPath -Path $rawPath

    # ---------- 片段 4：Git（单次聚合调用） ----------
    $gitPart = ''
    $git = Get-GitPromptInfo
    if ($null -ne $git) {
        $branchColor = $cGitOk
        $statusBits = [System.Collections.Generic.List[string]]::new()
        if ($git.Ahead -gt 0)     { [void]$statusBits.Add($cNum + [char]0x2191 + $git.Ahead) }
        if ($git.Behind -gt 0)    { [void]$statusBits.Add($cNum + [char]0x2193 + $git.Behind) }
        if ($git.Staged -gt 0)    { [void]$statusBits.Add($cGitOk + '+' + $git.Staged) }
        if ($git.Unstaged -gt 0)  { [void]$statusBits.Add($cGitChg + '~' + $git.Unstaged) }
        if ($git.Untracked -gt 0) { [void]$statusBits.Add($cDim + '?' + $git.Untracked) }
        if ($git.Conflicted -gt 0) {
            [void]$statusBits.Add($cGitBad + '!!' + $git.Conflicted)
            $branchColor = $cGitBad
        } elseif ($git.Staged + $git.Unstaged + $git.Untracked -gt 0) {
            $branchColor = $cGitChg
        }
        $gitPart = ' ' + $cDim + 'on ' + $branchColor + $git.Branch
        if ($statusBits.Count -gt 0) { $gitPart += ' ' + ($statusBits -join ' ') }
        $gitPart += $cReset
    }

    # ---------- 片段 5：后台任务 ----------
    $jobPart = ''
    try {
        $running = @(Get-Job -ErrorAction SilentlyContinue | Where-Object { $_.State -eq 'Running' }).Count
        if ($running -gt 0) { $jobPart = ' ' + $cNum + [char]0x25CF + $running }
    } catch { }

    # ---------- 片段 6：上条命令耗时（PS7+ 的历史条目带执行时间，5.1 自动跳过） ----------
    $durPart = ''
    try {
        $last = Get-History -Count 1 -ErrorAction Stop
        if ($null -ne $last -and $null -ne $last.PSObject.Properties['EndExecutionTime']) {
            $dur = Format-PromptDuration -Elapsed ($last.EndExecutionTime - $last.StartExecutionTime)
            if ($dur) { $durPart = ' ' + $cNum + [char]0x29D7 + $dur }
        }
    } catch { }

    # ---------- 窗口标题 ----------
    try {
        $adminTitle = if (Test-Administrator) { '[ADMIN] ' } else { '' }
        $Host.UI.RawUI.WindowTitle = $adminTitle + $rawPath + ' - PowerShell ' + $PSVersionTable.PSVersion
    } catch { }

    # ---------- 纯文本回退（重定向/不支持 ANSI 的终端） ----------
    if (-not $script:UseAnsiColor) {
        $plainGit = if ($git) { ' on ' + $git.Branch } else { '' }
        $plainErr = if ($failed) { ' [' + $exitCode + ']' } else { '' }
        return ($shortPath + $plainGit + $plainErr + '> ')
    }

    # ---------- 组装双行 prompt ----------
    $line1 = $errPart + $venvPart + $cPath + $shortPath + $cReset + $gitPart + $jobPart + $durPart
    $arrow = if ($failed) { $cErr } else { $cOk }
    $adminMark = if (Test-Administrator) { $cAdmin + [char]0x26A1 + ' ' } else { '' }
    $blankLine = if ($env:DOTFILES_PROMPT_COMPACT -eq '1') { '' } else { "`n" }

    return ($blankLine + $line1 + "`n" + $adminMark + $arrow + [char]0x276F + $cReset + ' ')
}

# ---------- starship：存在则覆盖内置 prompt，与 zsh 侧外观统一 ----------
if (Test-Command starship) {
    try {
        Invoke-Expression ((starship init powershell | Out-String))
    } catch {
        # starship 初始化失败时保留内置 prompt
    }
}
