#!/usr/bin/env bash
# brew/_common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/_module_loader.sh" "BREW_DIR"
has_brew() { has_cmd brew; }
