#!/usr/bin/env bash
# zsh/_common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/_module_loader.sh" "ZSH_DIR"
has_zsh() { has_cmd zsh; }
has_zsh || return 0

get_zsh_version() {
  has_zsh || return 1
  zsh --version 2>&1 | head -1
}
