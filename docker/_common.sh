#!/usr/bin/env bash
# docker/_common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/_module_loader.sh" "DOCKER_DIR"
has_docker() { has_cmd docker; }
has_compose() { docker compose version > /dev/null 2>&1 || has_cmd docker-compose; }

# 国内镜像源（可被 NO_MIRROR=1 禁用）
docker_apt_mirror() {
  if [[ -n "${NO_MIRROR:-}" ]]; then echo ""; else echo "https://mirrors.ustc.edu.cn/ubuntu"; fi
}
docker_debian_mirror() {
  if [[ -n "${NO_MIRROR:-}" ]]; then echo ""; else echo "https://mirrors.ustc.edu.cn/debian"; fi
}
docker_fedora_mirror() {
  if [[ -n "${NO_MIRROR:-}" ]]; then echo ""; else echo "https://mirrors.ustc.edu.cn/fedora"; fi
}
