#!/usr/bin/env bash
# zsh/_common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/_module_loader.sh" "ZSH_DIR"
has_zsh() { has_cmd zsh; }
has_zsh || return 0

