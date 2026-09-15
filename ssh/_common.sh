#!/usr/bin/env bash
# ssh/_common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/_module_loader.sh" "SSH_DIR"
has_ssh() { has_cmd ssh; }
has_ssh || return 0

get_ssh_version() {
  has_ssh || return 1
  # ssh -V 输出到 stderr，需重定向合并
  ssh -V 2>&1 | head -1
}

# 获取文件权限位（GNU stat 与 BSD stat 兼容，软链跟随）
get_file_mode() {
  stat -L -c '%a' "$1" 2>/dev/null || stat -L -f '%Lp' "$1" 2>/dev/null || echo '?'
}
