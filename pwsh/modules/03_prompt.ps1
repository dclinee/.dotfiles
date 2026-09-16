#requires -Version 5.1
<# 提示符与智能跳转：starship 优先（与 zsh 侧主题统一），缺失时使用内置轻量 prompt #>

# ---------- zoxide（若安装）：提供 z/zi 智能跳转 ----------
if (Test-Command zoxide) {
    try {
        Invoke-Expression ((zoxide init powershell | Out-String))
    } catch {
        # 初始化失败静默忽略，不影响 prompt
    }
}

# ---------- 内置 prompt（starship 缺失时生效；starship 存在则在下方覆盖本函数） ----------
function global:prompt {
    $reset = [char]27 + '[0m'
    $cyan  = [char]27 + '[36m'
    $green = [char]27 + '[32m'
    $yellow = [char]27 + '[33m'
    $red   = [char]27 + '[31m'
    $bold  = [char]27 + '[1m'
    if (-not $script:UseAnsiColor) {
        $reset = $cyan = $green = $yellow = $red = $bold = ''
    }

    # 路径：$HOME 缩写为 ~
    $loc = Get-Location
    $pathDisplay = $loc.Path
    if ($null -ne $HOME -and $pathDisplay.StartsWith($HOME)) {
        $pathDisplay = '~' + $pathDisplay.Substring($HOME.Length)
    }

    # 管理员标识
    $adminMark = ''
    if (Test-Administrator) { $adminMark = ($red + '# ' + $reset) }

    # Git 分支与脏标记
    $gitPart = ''
    $branch = Get-GitBranch
    if ($null -ne $branch -and $branch -ne '') {
        $branchColor = $green
        if (Test-GitDirty) { $branchColor = $red }
        $gitPart = ' ' + $yellow + 'git:' + $branchColor + $branch + $reset
    }

    # 退出码（上一条命令失败时显示）
    $exitPart = ''
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        $exitPart = ' ' + $red + '[' + $LASTEXITCODE + ']' + $reset
    }

    return ($bold + $cyan + $pathDisplay + $reset + $gitPart + $exitPart + ' ' + $adminMark + $bold + '>' + $reset + ' ')
}

# ---------- starship：存在则覆盖内置 prompt，与 zsh 侧外观统一 ----------
if (Test-Command starship) {
    try {
        Invoke-Expression ((starship init powershell | Out-String))
    } catch {
        # starship 初始化失败时保留内置 prompt
    }
}
