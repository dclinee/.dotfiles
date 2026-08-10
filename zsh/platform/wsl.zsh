#!/usr/bin/env zsh

# ======================
# WSL (Windows Subsystem for Linux) 专用配置
# ======================

# --- WSL 检测辅助 ---
_is_wsl2() { [[ -f /proc/version ]] && grep -qi "microsoft\|wsl2\|wsl" /proc/version 2>/dev/null; }

# --- Windows 路径集成 ---
# 把常见 Windows 可执行目录放入 PATH（去重）
_win_add_path() {
  local d
  for d in "$@"; do
    [[ -d "$d" ]] || continue
    case ":$PATH:" in
      *":$d:"*) : ;;  # 已存在
      *) export PATH="$d:$PATH" ;;
    esac
  done
}

# Windows 系统目录（WSL 自动挂载 Windows C:\ → /mnt/c）
WSL_WIN_ROOT="${WSL_WIN_ROOT:-/mnt/c}"
if [[ -d "$WSL_WIN_ROOT/Windows/System32" ]]; then
  _win_add_path \
    "$WSL_WIN_ROOT/Windows/System32" \
    "$WSL_WIN_ROOT/Windows" \
    "$WSL_WIN_ROOT/Windows/System32/Wbem" \
    "$WSL_WIN_ROOT/Windows/System32/WindowsPowerShell/v1.0" \
    "$WSL_WIN_ROOT/Users/${WSL_WIN_USER:-$(powershell.exe -NoProfile -Command '$env:UserName' 2>/dev/null | tr -d '\r')}/AppData/Local/Microsoft/WindowsApps" \
    "$WSL_WIN_ROOT/Program Files/Git/cmd"
fi

# 常用 Windows 工具（在 WSL 中调用 Windows 程序）
alias pwsh='powershell.exe -NoProfile -Command'
alias explorer='explorer.exe'
alias win-cmd='cmd.exe /c'
alias code='code.exe' 2>/dev/null || true  # VS Code (需要 Windows 端安装并启用 Remote-WSL)
# 打开当前目录在 Windows 资源管理器
alias openwin='explorer.exe "$(wslpath -w "$(pwd)" 2>/dev/null || pwd)"'
# 复制到 Windows 剪贴板 (需要 xclip 替代方案: clip.exe)
alias winclip='clip.exe'
# 从 Windows 剪贴板粘贴 (PowerShell Get-Clipboard)
alias winpaste='powershell.exe -NoProfile -Command "Get-Clipboard" 2>/dev/null'

# --- WSL 剪贴板同步 ---
# 让 Zsh/Vim 中的 xclip 行为能同步到 Windows 剪贴板
# 定义全局别名 fallback（xclip/wl-clipboard 不可用时）
if ! command -v xclip > /dev/null 2>&1 && ! command -v wl-copy > /dev/null 2>&1; then
  # 接管 DISPLAY，使用 Windows 剪贴板作为系统剪贴板
  export CLIPBOARD_PROVIDER="${WSL_WIN_ROOT}/Windows/System32/clip.exe"
  # 通用复制函数（跨平台一致性入口）
  clip-copy() {
    if [[ -t 0 ]]; then
      # 没有管道输入，复制参数
      printf '%s' "$*" | clip.exe
    else
      # stdin 重定向
      clip.exe
    fi
  }
fi

# --- WSLg 图形支持 (WSL2 0.58+) ---
# WSLg 自动设置 DISPLAY，确保 GUI 应用可用
if [[ -z "${DISPLAY:-}" ]] && command -v Xwayland > /dev/null 2>&1; then
  export DISPLAY=:0
fi

# Wayland 如果有 WSLg socket
if [[ -S "/mnt/wslg/.X11-unix/X0" ]]; then
  export XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir
fi

# 让 GUI 应用中文显示正常 (如 WSLg 缺字体时)
if [[ -d "${WSL_WIN_ROOT}/Windows/Fonts" ]]; then
  export FONTCONFIG_PATH="/etc/fonts:${WSL_WIN_ROOT}/Windows/Fonts"
fi

# --- HOME 与 Windows 互通 ---
# 快捷跳转到 Windows 用户目录
WSL_WIN_HOME="${WSL_WIN_HOME:-$WSL_WIN_ROOT/Users/${USER}}"
if [[ -d "$WSL_WIN_HOME" ]]; then
  alias cdwin='cd "$WSL_WIN_HOME"'
  alias desktop='cd "$WSL_WIN_HOME/Desktop"'
  alias downloads='cd "$WSL_WIN_HOME/Downloads"'
  alias documents='cd "$WSL_WIN_HOME/Documents"'
fi

# --- 文件系统优化 ---
# WSL /mnt/c 性能比 Linux 文件系统慢 10 倍左右
# 建议代码放在 ~/ (Linux 端)，通过 symlink 共享 Windows 文件
if _is_wsl2; then
  # 提示: 避免在 /mnt/c 进行 git/npm/pip 操作
  # 仅在 .zshenv 输出一次
  if [[ -z "${WSL_TIP_SHOWN:-}" ]]; then
    export WSL_TIP_SHOWN=1
    # 静默即可，不刷屏
  fi

  # WSL2 默认 umask 0000 的修正（部分发行版）
  umask 022 2>/dev/null || true
fi

# --- Docker Desktop (WSL 后端) ---
# Windows 端安装 Docker Desktop + WSL 集成后，自动创建 /var/run/docker.sock
if command -v docker.exe > /dev/null 2>&1 && ! command -v docker > /dev/null 2>&1; then
  alias docker='docker.exe'
  alias docker-compose='docker-compose.exe'
fi

# --- SSH 通线（Windows 端的 OpenSSH Agent 转发到 WSL） ---
# 使用 npiperelay + socat 把 Windows 端 ssh-agent 转发到 WSL
if command -v socat > /dev/null 2>&1 && command -v npiperelay.exe > /dev/null 2>&1; then
  export SSH_AUTH_SOCK="${HOME}/.ssh/agent.sock"
  # 如果该 socket 没被监听，尝试启动一次（失败不影响）
  if ! pgrep -f "npiperelay.exe.*ssh-agent" > /dev/null 2>&1; then
    (
      rm -f "${SSH_AUTH_SOCK}" 2>/dev/null || true
      socat "UNIX-LISTEN:${SSH_AUTH_SOCK},fork,umask=007" \
            "EXEC:npiperelay.exe -ei -s //./pipe/openssh-ssh-agent,nofork" \
            > /dev/null 2>&1 &
    ) 2>/dev/null || true
  fi
fi

# --- Git 优化（跨 WSL 文件系统）---
# 如果 Git 仓库在 /mnt/c 上，添加以下可加速 (WSL2 的跨 OS 文件系统较慢)
export GIT_DISCOVERY_ACROSS_FILESYSTEM=true

# --- 包管理器 (WSL 通常是 Ubuntu/Debian) ---
# 继承 linux.zsh，但添加 Winget 支持 (从 WSL 调用 Windows 包管理)
if command -v winget.exe > /dev/null 2>&1; then
  alias winget='winget.exe'
  alias update-win='winget upgrade --all'
fi

# --- WSL 版本快捷查看 ---
wsl-info() {
  echo "WSL 版本信息:"
  if [[ -f /proc/version ]]; then
    echo "  内核: $(cat /proc/version | head -c 100)..."
  fi
  if command -v wsl.exe > /dev/null 2>&1; then
    echo "  WSL: $(wsl.exe --version 2>/dev/null | tr -d '\r' | paste -sd ',' -)"
  fi
  echo "  Windows 根: ${WSL_WIN_ROOT}"
  echo "  Windows 用户目录: ${WSL_WIN_HOME:-未检测到}"
  echo "  DISPLAY: ${DISPLAY:-未设置 (WSLg 或 X Server 不可用)}"
  echo "  SSH_AUTH_SOCK: ${SSH_AUTH_SOCK:-未设置 (用 Windows SSH Agent)}"
}

# WSL 启动检查（仅打印一次，且交互模式）
if [[ -o interactive ]] && [[ -z "${WSL_INIT_DONE:-}" ]]; then
  export WSL_INIT_DONE=1
  # 不打印，保持干净
fi
