#!/usr/bin/env bash
# git/_common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/_module_loader.sh" "GIT_DIR"
has_git() { has_cmd git; }
