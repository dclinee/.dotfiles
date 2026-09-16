#!/usr/bin/env bash
# vim/_common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/_module_loader.sh" "VIM_DIR"
has_vim() { has_cmd vim; }
has_vim || return 0


# 是否有免密 sudo（root 直接视为有）
have_sudo() {
  if [[ $EUID -eq 0 ]]; then
    return 0
  fi
  sudo -n true 2>/dev/null
}
