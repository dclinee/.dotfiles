#!/usr/bin/env bash
# emacs/_common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/_module_loader.sh" "EMACS_DIR"
has_emacs() { has_cmd emacs; }
has_emacs || return 0  # 允许在无 emacs 环境下 source

get_emacs_version() {
  has_emacs || return 1
  emacs --version 2>&1 | head -1
}
