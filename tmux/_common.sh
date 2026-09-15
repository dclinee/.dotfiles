#!/usr/bin/env bash
# tmux/_common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/_module_loader.sh" "TMUX_DIR"
has_tmux() { has_cmd tmux; }
