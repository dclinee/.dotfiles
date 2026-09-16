#!/usr/bin/env bash
# wezterm/_common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/_module_loader.sh" "WEZTERM_DIR"
has_wezterm() { has_cmd wezterm; }
has_wezterm || return 0

