#!/usr/bin/env zsh

# ======================
# Starship 提示符配置（含字体检测与降级）
# ======================
#
# 工作原理：
# 1. 检测系统是否安装了 Nerd Font
# 2. 如果有 Nerd Font → 使用 starship.toml（含 Nerd Font 图标）
# 3. 如果无 Nerd Font → 使用 starship_fallback.toml（纯 Unicode 符号）

ZSH_HOME="${ZSH_HOME:-${HOME}/.dotfiles/zsh}"
FALLBACK_CONFIG="${ZSH_HOME}/starship/starship_fallback.toml"
MAIN_CONFIG="${ZSH_HOME}/starship/starship.toml"

# 跨平台获取文件 mtime（epoch 秒）
# GNU stat 用 -c %Y，BSD stat（macOS 自带）用 -f %m
_dotfiles_get_mtime() {
  local file="$1"
  # 通过尝试 GNU 语法探测实现，结果在全局变量中缓存（仅探测一次）
  if [[ -z "${_dotfiles_stat_flag:-}" ]]; then
    if stat -c %Y / > /dev/null 2>&1; then
      typeset -g _dotfiles_stat_flag='-c %Y'   # GNU
    else
      typeset -g _dotfiles_stat_flag='-f %m'   # BSD/macOS
    fi
  fi
  stat ${_dotfiles_stat_flag} "$file" 2>/dev/null || echo 0
}

# 检测 Nerd Font (带智能缓存 + mtime 校验)
_has_nerd_font() {
  local cache_file="${HOME}/.cache/zsh/nerd_font_cache"
  local font_dir="${HOME}/.local/share/fonts"

  # 快速路径：检查字体缓存文件是否已存在（无需解析内容）
  if [[ -f "$cache_file" ]]; then
    # 检查字体目录 mtime 是否变化（字体安装/删除后会更新 mtime）
    local cache_mtime font_mtime
    cache_mtime=$(_dotfiles_get_mtime "$cache_file")
    font_mtime=$(_dotfiles_get_mtime "$font_dir")

    if [[ "$font_mtime" -le "$cache_mtime" ]]; then
      # 字体目录未变化，使用缓存结果
      local cache_result=$(tail -1 "$cache_file" 2>/dev/null)
      [[ "$cache_result" == "yes" ]] && return 0
      return 1
    fi
  fi

  # 执行实际检测
  local found=1

  # 方法1: fc-list
  if command -v fc-list > /dev/null 2>&1; then
    fc-list : family 2>/dev/null | grep -qi "Nerd" && found=0
  fi

  # 方法2: 检查常见字体目录
  if [[ $found -ne 0 ]]; then
    local dir
    for dir in \
      "${HOME}/.local/share/fonts" \
      "${HOME}/.fonts" \
      "/usr/local/share/fonts" \
      "/usr/share/fonts" \
      "/usr/share/fonts/truetype" \
      "/usr/share/fonts/opentype"; do
      [[ -d "${dir}" ]] && find "${dir}" -iname "*Nerd*" -print -quit 2>/dev/null | grep -q . && found=0 && break
    done
  fi

  # 方法3: brew 字体
  if [[ $found -ne 0 ]] && command -v brew > /dev/null 2>&1; then
    local prefix="${HOMEBREW_PREFIX:-/home/linuxbrew/.linuxbrew}"
    [[ -d "${prefix}/share/fonts" ]] && find "${prefix}/share/fonts" -iname "*Nerd*" -print -quit 2>/dev/null | grep -q . && found=0
  fi

  # 写入缓存（记录检测日期 + 结果，便于调试和过期判断）
  mkdir -p "${HOME}/.cache/zsh" 2>/dev/null
  echo "$(date +%Y-%m-%d)" > "$cache_file"
  [[ $found -eq 0 ]] && echo "yes" >> "$cache_file" || echo "no" >> "$cache_file"

  return $found
}

# ======================
# 主逻辑
# ======================

if command -v starship > /dev/null 2>&1; then
  if _has_nerd_font; then
    export STARSHIP_CONFIG="${MAIN_CONFIG}"
  else
    # starship_fallback.toml 已作为独立文件提交，无需动态生成
    if [[ -f "${FALLBACK_CONFIG}" ]]; then
      export STARSHIP_CONFIG="${FALLBACK_CONFIG}"
    else
      echo "[dotfiles] 警告: ${FALLBACK_CONFIG} 缺失，Starship 将使用默认配置" >&2
    fi
  fi
  eval "$(starship init zsh)"
else
  PROMPT='%F{blue}%~%f %# '
  RPROMPT='%F{8}%*%f'
fi
