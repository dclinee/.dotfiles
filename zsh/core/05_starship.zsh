#!/usr/bin/env zsh

# ======================
# Starship 提示符配置（含字体检测与降级）
# ======================
#
# 工作原理：
# 1. 检测系统是否安装了 Nerd Font
# 2. 如果有 Nerd Font → 使用 starship.toml（含 Nerd Font 图标）
# 3. 如果无 Nerd Font → 自动生成降级版配置（使用纯 Unicode 符号）

ZSH_HOME="${ZSH_HOME:-${HOME}/.dotfiles/zsh}"
FALLBACK_CONFIG="${ZSH_HOME}/starship_fallback.toml"
MAIN_CONFIG="${ZSH_HOME}/starship.toml"

# 检测 Nerd Font (带每日缓存)
_has_nerd_font() {
  # 缓存检查 - 每天只检测一次
  local cache_file="${HOME}/.cache/zsh/nerd_font_cache"
  local today=$(date +'%Y-%m-%d')
  if [[ -f "$cache_file" ]]; then
    local cache_date=$(head -1 "$cache_file" 2>/dev/null)
    local cache_result=$(tail -1 "$cache_file" 2>/dev/null)
    if [[ "$cache_date" == "$today" ]] && [[ -n "$cache_result" ]]; then
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

  # 写入缓存
  mkdir -p "${HOME}/.cache/zsh" 2>/dev/null
  echo "$today" > "$cache_file"
  [[ $found -eq 0 ]] && echo "yes" >> "$cache_file" || echo "no" >> "$cache_file"

  return $found
}

# 生成降级版配置（使用标准 Unicode 符号）
_generate_fallback() {
  cat > "${FALLBACK_CONFIG}" << 'FALLBACK_EOF'
"$schema" = 'https://starship.rs/config-schema.json'

format = """
[▓▒░](color_orange)\
$os\
$username\
[▒▓](bg:color_yellow fg:color_orange)\
$directory\
[▒▓](fg:color_yellow bg:color_aqua)\
$git_branch\
$git_status\
[▒▓](fg:color_aqua bg:color_blue)\
$c\
$cpp\
$rust\
$golang\
$nodejs\
$php\
$java\
$kotlin\
$haskell\
$python\
[▒▓](fg:color_blue bg:color_bg3)\
$docker_context\
$conda\
$pixi\
[▒▓](fg:color_bg3 bg:color_bg1)\
$time\
[░▒▓](fg:color_bg1)\
$line_break$character"""

palette = 'gruvbox_dark'

[palettes.gruvbox_dark]
color_fg0 = '#fbf1c7'
color_bg1 = '#3c3836'
color_bg3 = '#665c54'
color_blue = '#458588'
color_aqua = '#689d6a'
color_green = '#98971a'
color_orange = '#d65d0e'
color_purple = '#b16286'
color_red = '#cc241d'
color_yellow = '#d79921'

[os]
disabled = false
style = "bg:color_orange fg:color_fg0"

[os.symbols]
Windows = "⊞"
Ubuntu = "🐧"
SUSE = "🦎"
Raspbian = "🪺"
Mint = "🌿"
Macos = ""
Manjaro = "🟢"
Linux = "🐧"
Gentoo = "😈"
Fedora = "🎩"
Alpine = "🏔"
Amazon = "📦"
Android = "🤖"
Arch = "🏛"
Artix = "🏛"
EndeavourOS = "🔭"
CentOS = "⚙"
Debian = "🌀"
Redhat = "🎩"
RedHatEnterprise = "🎩"
Pop = "💫"

[username]
show_always = true
style_user = "bg:color_orange fg:color_fg0"
style_root = "bg:color_orange fg:color_fg0"
format = '[ $user ]($style)'

[directory]
style = "fg:color_fg0 bg:color_yellow"
format = "[ $path ]($style)"
truncation_length = 3
truncation_symbol = "…/"

[directory.substitutions]
"Documents" = "📄 "
"Downloads" = "⬇ "
"Music" = "🎵 "
"Pictures" = "🖼 "
"Developer" = "💻 "

[git_branch]
symbol = "⎇"
style = "bg:color_aqua"
format = '[[ $symbol $branch ](fg:color_fg0 bg:color_aqua)]($style)'

[git_status]
style = "bg:color_aqua"
format = '[[($all_status$ahead_behind )](fg:color_fg0 bg:color_aqua)]($style)'

[nodejs]
symbol = "⬢"
style = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'

[c]
symbol = "◆"
style = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'

[cpp]
symbol = "◇"
style = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'

[rust]
symbol = "⚙"
style = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'

[golang]
symbol = "▲"
style = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'

[php]
symbol = "🧱"
style = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'

[java]
symbol = "☕"
style = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'

[kotlin]
symbol = "🟣"
style = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'

[haskell]
symbol = "λ"
style = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'

[python]
symbol = "🐍"
style = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'

[docker_context]
symbol = "🐳"
style = "bg:color_bg3"
format = '[[ $symbol( $context) ](fg:#83a598 bg:color_bg3)]($style)'

[conda]
style = "bg:color_bg3"
format = '[[ $symbol( $environment) ](fg:#83a598 bg:color_bg3)]($style)'

[pixi]
style = "bg:color_bg3"
format = '[[ $symbol( $version)( $environment) ](fg:color_fg0 bg:color_bg3)]($style)'

[time]
disabled = false
time_format = "%R"
style = "bg:color_bg1"
format = '[[ 🕐 $time ](fg:color_fg0 bg:color_bg1)]($style)'

[line_break]
disabled = false

[character]
disabled = false
success_symbol = '[➤](bold fg:color_green)'
error_symbol = '[➤](bold fg:color_red)'
vimcmd_symbol = '[❮](bold fg:color_green)'
vimcmd_replace_one_symbol = '[❮](bold fg:color_purple)'
vimcmd_replace_symbol = '[❮](bold fg:color_purple)'
vimcmd_visual_symbol = '[❮](bold fg:color_yellow)'
FALLBACK_EOF
}

# ======================
# 主逻辑
# ======================

if command -v starship > /dev/null 2>&1; then
  if _has_nerd_font; then
    export STARSHIP_CONFIG="${MAIN_CONFIG}"
  else
    [[ ! -f "${FALLBACK_CONFIG}" ]] && _generate_fallback
    export STARSHIP_CONFIG="${FALLBACK_CONFIG}"
  fi
  eval "$(starship init zsh)"
else
  PROMPT='%F{blue}%~%f %# '
  RPROMPT='%F{8}%*%f'
fi
