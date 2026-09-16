#!/usr/bin/env bash
# lib/make-output.sh — Makefile install 输出美化库
# 提供进度跟踪、计时、横幅、汇总表（hack/tech 风格）

if [[ -z "${__MAKE_OUTPUT_SH_LOADED:-}" ]]; then
__MAKE_OUTPUT_SH_LOADED=1

# 颜色（NO_COLOR 标准: https://no-color.org/）
if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
  _R="" _G="" _Y="" _C="" _M="" _K="" _X="" _BD="" _DM=""
else
  _R=$'\033[31m' _G=$'\033[32m' _Y=$'\033[33m'
  _C=$'\033[36m' _M=$'\033[35m' _K=$'\033[90m' _X=$'\033[0m'
  _BD=$'\033[1m' _DM=$'\033[2m'
fi

_BW=42  # box 内部宽度

# 重复字符: _rep <char> <count>
_rep() { local s="" i; for ((i = 0; i < $2; i++)); do s+="$1"; done; printf '%s' "$s"; }

# ── 横幅 ── make_banner <total> <platform>
make_banner() {
  local total="$1" platform="$2" dt rule
  dt="$(date +%Y-%m-%d)"
  rule=$(_rep "─" "$_BW")
  printf "${_C}┌${rule}┐${_X}\n"
  local t1="  Dotfiles Installer"
  printf "${_C}│${_X}${_BD}%s${_X}" "$t1"
  printf '%*s' "$((_BW - ${#t1}))" ''
  printf "${_C}│${_X}\n"
  local t2="  ${total} modules · ${platform} · ${dt}"
  printf "${_C}│${_X}${_DM}%s${_X}" "$t2"
  printf '%*s' "$((_BW - ${#t2}))" ''
  printf "${_C}│${_X}\n"
  printf "${_C}└${rule}┘${_X}\n"
}

# ── 步骤开始 ── make_step <num> <total> <name>
make_step() {
  printf "${_BD}${_M}[%s/%s]${_X} ${_C}▶ %s${_X}\n" "$1" "$2" "$3"
}

# ── 步骤成功 ── make_ok <name> <start_epoch>
make_ok() {
  local el=$(( $(date +%s) - $2 ))
  printf "  ${_G}✓ %s${_X} ${_DM}%ss${_X}\n" "$1" "$el"
}

# ── 步骤失败 ── make_fail <name> <start_epoch>
make_fail() {
  local el=$(( $(date +%s) - $2 ))
  printf "  ${_R}✗ %s${_X} ${_DM}%ss${_X}\n" "$1" "$el"
}

# ── 汇总表 ── make_summary <results_file> <total>
make_summary() {
  local rf="$1" total="$2" ok=0 fail=0 tt=0 rule
  rule=$(_rep "─" "$_BW")
  if [[ -f "$rf" ]]; then
    ok=$(grep -c "^OK|" "$rf" 2>/dev/null || echo 0)
    fail=$(grep -c "^FAIL|" "$rf" 2>/dev/null || echo 0)
    tt=$(awk -F'|' '{s += $3} END{printf "%d", s}' "$rf" 2>/dev/null || echo 0)
  fi
  printf "\n"
  printf "${_C}┌${rule}┐${_X}\n"
  local hdr="  Results  ${ok}/${total} OK  ${tt}s"
  printf "${_C}│${_X}${_BD}%s${_X}" "$hdr"
  printf '%*s' "$((_BW - ${#hdr}))" ''
  printf "${_C}│${_X}\n"
  printf "${_C}├${rule}┤${_X}\n"
  if [[ -f "$rf" ]]; then
    while IFS='|' read -r st nm tm; do
      [[ -z "$st" ]] && continue
      local pad=$(( _BW - 6 - ${#nm} - ${#tm} ))
      if [[ "$st" == "OK" ]]; then
        printf "${_C}│${_X}  ${_G}✓${_X} %s ${_DM}%ss${_X}" "$nm" "$tm"
      else
        printf "${_C}│${_X}  ${_R}✗${_X} %s ${_DM}%ss${_X}" "$nm" "$tm"
      fi
      printf '%*s' "$pad" ''
      printf "${_C}│${_X}\n"
    done < "$rf"
  fi
  printf "${_C}└${rule}┘${_X}\n"
}

fi