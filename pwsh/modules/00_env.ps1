#requires -Version 5.1
<# 环境变量、PATH 与 PSReadLine 行编辑器配置 #>

# ---------- 编码：PS5.1 默认 GBK/CP936，统一为 UTF-8，避免中文输出乱码 ----------
try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
} catch {
    # 极旧环境降级
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
}

# ---------- DOTFILES_ROOT（未显式设置时由 _common.ps1 按自身位置反推仓库根） ----------
if ($null -eq $env:DOTFILES_ROOT -or $env:DOTFILES_ROOT -eq '') {
    $env:DOTFILES_ROOT = Get-DotfilesRoot
}

# ---------- PATH 增补（存在才加，幂等） ----------
function Add-PathUnique {
    param([Parameter(Mandatory = $true)][string]$PathToAdd)
    if (-not (Test-Path -LiteralPath $PathToAdd)) { return }
    $separator = [System.IO.Path]::PathSeparator
    $existing = ($env:PATH -split [regex]::Escape($separator))
    foreach ($p in $existing) {
        if ($p -and ($p.TrimEnd([System.IO.Path]::DirectorySeparatorChar) -eq
                     $PathToAdd.TrimEnd([System.IO.Path]::DirectorySeparatorChar))) {
            return
        }
    }
    $env:PATH = $PathToAdd + $separator + $env:PATH
}

if (Get-IsWindows) {
    Add-PathUnique (Join-Path $env:USERPROFILE '.local\bin')
    Add-PathUnique (Join-Path $env:USERPROFILE 'scoop\shims')
} else {
    Add-PathUnique (Join-Path $HOME '.local/bin')
}

# ---------- PSReadLine（PS5.1 自带 2.0；PredictionSource 需要 2.1+，按需降级） ----------
if (Get-Module -ListAvailable -Name PSReadLine) {
    try {
        Import-Module PSReadLine -ErrorAction Stop

        Set-PSReadLineOption -EditMode Windows
        Set-PSReadLineOption -BellStyle None
        Set-PSReadLineOption -HistoryNoDuplicates

        # 版本敏感参数（PSReadLine 2.1+）独立容错，失败不影响下方核心键绑定
        try { Set-PSReadLineOption -HistorySearchCursorMovesToEnd -ErrorAction Stop } catch { }

        # Tab 菜单补全
        Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
        # 上下箭头按当前输入前缀搜索历史（与 zsh history-substring-search 体验一致）
        Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
        Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
        # Ctrl+D 退出（显式声明便于维护）
        Set-PSReadLineKeyHandler -Key Ctrl+d -Function DeleteCharOrExit

        # 内联预测仅 PSReadLine 2.1+ 支持，老版本静默跳过
        try {
            Set-PSReadLineOption -PredictionSource HistoryAndPlugin -ErrorAction Stop
            Set-PSReadLineOption -PredictionViewStyle ListView -ErrorAction Stop
            Set-PSReadLineOption -ShowToolTips
        } catch {
            # PSReadLine 2.0（Win11 自带的 PS5.1）无预测功能，忽略
        }
    } catch {
        # PSReadLine 加载失败不应影响 shell 启动
    }
}

# ---------- 常用环境变量 ----------
if ([string]::IsNullOrEmpty($env:EDITOR)) {
    if (Test-Command nvim) { $env:EDITOR = 'nvim' }
    elseif (Test-Command vim) { $env:EDITOR = 'vim' }
}
