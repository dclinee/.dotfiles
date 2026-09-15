#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/_module_loader.sh" "EDITORCONFIG_DIR"
has_editorconfig() { [[ -f "${HOME}/.editorconfig" ]]; }
