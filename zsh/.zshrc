#!/usr/bin/env zsh

# ======================
# 主入口配置文件
# ======================

# 加载核心配置模块
for file in "${HOME}/.dotfiles/zsh/core"/*.zsh; do
  [ -f "$file" ] && [ ! -d "$file" ] && source "$file"
done

# 按系统加载平台配置
case "$(uname -s)" in
  Darwin)
    [ -f "${ZSH_HOME}/platform/macos.zsh" ] && source "${ZSH_HOME}/platform/macos.zsh"
    ;;
  Linux)
    [ -f "${ZSH_HOME}/platform/linux.zsh" ] && source "${ZSH_HOME}/platform/linux.zsh"
    # WSL 是 Linux 内核，先加载 Linux 配置，再叠加 WSL 专属配置
    # (双加载模式：WSL 特有增强不覆盖 Linux 通用设置)
    if grep -qi "microsoft\|wsl2\|wsl" /proc/version 2>/dev/null; then
      [ -f "${ZSH_HOME}/platform/wsl.zsh" ] && source "${ZSH_HOME}/platform/wsl.zsh"
    fi
    ;;
esac

# 加载本地自定义配置（不会被仓库覆盖）
[ -f "${HOME}/.zshrc.local" ] && source "${HOME}/.zshrc.local"

# 启动性能计时输出（ZSH_PROFILE=1 时）
if [[ "${ZSH_PROFILE:-0}" == "1" ]] && [[ -n "${_zsh_start_time:-}" ]]; then
  zmodload zsh/datetime 2>/dev/null
  # 注: 不能用 ${(int)_elapsed}，那会输出变量类型名 "scalar"
  # 正确方式: 用 ${_elapsed%.*} 截断小数部分，或用 $(( int(_elapsed) )) 取整
  local _elapsed=$(( (EPOCHREALTIME - _zsh_start_time) * 1000 ))
  echo "[ZSH_PROFILE] 启动耗时: ${_elapsed%.*}ms" >&2
fi

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/dclee/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/dclee/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/home/dclee/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/home/dclee/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

# MindSpore GPU (WSL2) - CUDA 动态库路径（conda activate 后自动生效）
export PATH="/usr/local/cuda-11.6/bin:/usr/lib/wsl/lib:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/home/dclee/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/usr/lib/wsl/lib:/mnt/d/Trae CN/resources/app/modules/ai-agent/bin:/mnt/c/Program Files/Eclipse Adoptium/jdk-25.0.4.7-hotspot/bin:/mnt/c/WINDOWS/system32:/mnt/c/WINDOWS:/mnt/c/WINDOWS/System32/Wbem:/mnt/c/WINDOWS/System32/WindowsPowerShell/v1.0/:/mnt/c/WINDOWS/System32/OpenSSH/:/mnt/c/Program Files/dotnet/:/mnt/c/Program Files/nodejs/:/mnt/d/WezTerm:/mnt/c/Program Files/Git/cmd:/mnt/c/ProgramData/chocolatey/bin:/mnt/c/Program Files/Go/bin:/mnt/c/Program Files (x86)/ZeroTier/One/:/mnt/c/Program Files/PowerShell/7/:/mnt/c/Users/华为/.kimi-code/bin:/mnt/c/Users/华为/tools/msys64/msys64/usr/bin:/mnt/c/Users/华为/tools/msys64/msys64/mingw64/bin:/mnt/c/Users/��Ϊ/AppData/Local/Programs/Python/Python312/Scripts/:/mnt/c/Users/��Ϊ/AppData/Local/Programs/Python/Python312/:/mnt/c/Users/��Ϊ/AppData/Local/Programs/Python/Launcher/:/mnt/c/Users/��Ϊ/AppData/Local/Microsoft/WindowsApps:/mnt/c/Users/��Ϊ/AppData/Roaming/npm:/mnt/c/Program Files/Emacs/emacs-30.2/bin:/mnt/c/Users/华为/.local/bin:/mnt/c/Users/华为/tools/jdk17/jdk-17.0.20+8/bin:/mnt/c/Users/华为/tools/maven/apache-maven-3.9.9/bin:/mnt/c/Users/华为/Desktop/智能建筑/.tools/jdk-17/bin:/mnt/c/Users/华为/Desktop/智能建筑/.tools/apache-maven-3.9.9/bin:/mnt/c/Users/华为/AppData/Local/Programs/DockerDesktop/resources/bin:/mnt/c/Users/华为/go/bin:/mnt/d/Program Files/Huawei/DevEco Studio/bin:/mnt/c/Users/华为/.trae-cn/extensions/vscjava.vscode-java-debug-0.59.0-universal/bundled/scripts/noConfigScripts:/mnt/c/Users/华为/.trae-cn/extensions/ms-python.debugpy-2026.6.0-win32-x64/bundled/scripts/noConfigScripts:/mnt/c/Program Files/Eclipse Adoptium/jdk-25.0.4.7-hotspot/bin:/mnt/c/WINDOWS/system32:/mnt/c/WINDOWS:/mnt/c/WINDOWS/System32/Wbem:/mnt/c/WINDOWS/System32/WindowsPowerShell/v1.0/:/mnt/c/WINDOWS/System32/OpenSSH/:/mnt/c/Program Files/dotnet/:/mnt/c/Program Files/nodejs/:/mnt/d/WezTerm:/mnt/c/Program Files/Git/cmd:/mnt/c/ProgramData/chocolatey/bin:/mnt/c/Program Files/Go/bin:/mnt/c/Program Files (x86)/ZeroTier/One/:/mnt/c/Program Files/PowerShell/7/:/mnt/c/Users/��Ϊ/.kimi-code/bin:/mnt/c/Users/��Ϊ/tools/msys64/msys64/usr/bin:/mnt/c/Users/��Ϊ/tools/msys64/msys64/mingw64/bin:/mnt/c/Users/???/AppData/Local/Programs/Python/Python312/Scripts/:/mnt/c/Users/???/AppData/Local/Programs/Python/Python312/:/mnt/c/Users/???/AppData/Local/Programs/Python/Launcher/:/mnt/c/Users/???/AppData/Local/Microsoft/WindowsApps:/mnt/c/Users/???/AppData/Roaming/npm:/mnt/c/Program Files/Emacs/emacs-30.2/bin:/mnt/c/Users/��Ϊ/.local/bin:/mnt/c/Users/��Ϊ/tools/jdk17/jdk-17.0.20+8/bin:/mnt/c/Users/��Ϊ/tools/maven/apache-maven-3.9.9/bin:/mnt/c/Users/��Ϊ/Desktop/���ܽ���/.tools/jdk-17/bin:/mnt/c/Users/��Ϊ/Desktop/���ܽ���/.tools/apache-maven-3.9.9/bin:/mnt/c/Users/��Ϊ/AppData/Local/Programs/DockerDesktop/resources/bin:/mnt/c/Users/��Ϊ/go/bin:/mnt/d/Program Files/Huawei/DevEco Studio/bin:/mnt/c/Program Files/PowerShell/7:/mnt/d/Trae CN/resources/app/bin/lib:/mnt/d/Trae CN/resources/app/node_modules/@vscode/ripgrep/bin"
export LD_LIBRARY_PATH="/usr/local/cuda-11.6/lib64:/usr/lib/wsl/lib:"
