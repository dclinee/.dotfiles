#!/usr/bin/env bash
# rust/_common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/_module_loader.sh" "RUST_DIR"

# Rust 专用快捷函数
has_cargo()  { has_cmd cargo; }
has_rustup() { has_cmd rustup; }
has_rustc()  { has_cmd rustc; }
