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
  # 正确方式: 用 ${_elapsed%.*} 截断小数部分，或 $(( int(_elapsed) )) 取整
  _elapsed=$(( (EPOCHREALTIME - _zsh_start_time) * 1000 ))
  echo "[ZSH_PROFILE] 启动耗时: ${_elapsed%.*}ms" >&2
fi

# 机器特定配置（conda / CUDA / 项目专属 PATH 等）请写入 ~/.zshrc.local，
# 该文件已在上方 source，不提交仓库；切勿在此硬编码单机绝对路径。
# WSL 的 Windows 路径集成由 platform/wsl.zsh 条件式处理（目录存在才加入，自动去重）。

# uv 安装器写入的环境（~/.local/bin），文件存在时才加载
[ -f "${HOME}/.local/bin/env" ] && . "${HOME}/.local/bin/env"
