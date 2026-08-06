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
