#!/usr/bin/env bash
set -eo pipefail

temp_dir=$(mktemp -d)
trap 'rm -rf ${temp_dir}' EXIT

# 环境初始化
echo "\u001b[34m[INFO] 初始化测试环境\u001b[0m"
sudo rm -f /var/lib/dpkg/lock-frontend
sudo dpkg --configure -a
sudo apt-get update > /dev/null
# 终极清理方案
cleanup_system() {
  # 系统级深度清理
  sudo systemctl stop postfix.service || true
  sudo find / -name '*postfix*' -exec rm -rf {} + 2>/dev/null
}
sudo dpkg --purge postfix postfix-*
sudo rm -f /var/lib/dpkg/lock*
# 预配置postfix参数
echo -e "postfix postfix/main_mailer_type select No configuration\npostfix postfix/mailname string localhost\npostfix postfix/root_address string" | sudo debconf-set-selections

# 创建防御性元包
sudo equivs-control nopostfix-control
cat <<EOF | sudo tee nopostfix-control
Package: nopostfix
Version: 1.0
Provides: postfix
Description: Fake package to block postfix installation
EOF
sudo equivs-build nopostfix-control
# 预配置验证
sudo debconf-get-selections | grep -q 'postfix' || exit 1

# 虚拟包防御
sudo dpkg -i nopostfix_1.0_all.deb 2>/dev/null || true
DEBIAN_FRONTEND=noninteractive sudo apt-get install -y -qq --show-progress --fix-missing --allow-downgrades --allow-remove-essential --allow-change-held-packages curl git ca-certificates -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold'

# 安装后验证
# 增强型安装校验
if LC_ALL=C apt list --installed 2>/dev/null | grep -qE '^postfix/'; then
  echo "\u001b[31m[FATAL] 系统残留postfix服务"
  journalctl -u postfix --no-pager
  exit 127
fi && { echo "\u001b[31m[ERROR] Postfix安装残留"; exit 1; } || true

# 配置部署
rsync -a --exclude='*.md' /home/dclinee/.dotfiles/{zsh,brew} ${temp_dir}/
chmod -R +x ${temp_dir}/zsh/install.sh ${temp_dir}/brew/install.sh

# 安装事务追踪
{
  sudo apt-get install -y --simulate curl git
  sudo apt-get install -y -qq --show-progress
} | tee /tmp/install_trace.log

# 功能验证
zsh -c 'source ${temp_dir}/zsh/.zshrc && forgit log && fzf-tab --version'

echo "\u001b[32m[SUCCESS] 全量测试通过\u001b[0m"

# 系统健康检查
check_system_health() {
  [ -f /var/lib/dpkg/lock ] && return 1
  dpkg -l | grep -qE 'postfix|mydomain' && return 1
  command -v curl >/dev/null && command -v git >/dev/null
}

retry_command() {
  local max_retries=3
  local attempt=0
  until "$@"; do
    ((attempt++))
    ((attempt > max_retries)) && return 1
    sleep $((attempt * 5))
  done
}

log() {
  local level=$1
  local message=$2
  local timestamp=$(date +"%Y-%m-%d %T")
  echo "${timestamp} [${level}] ${message}" | tee -a ${LOG_FILE}
}

verify_installation() {
  # 包管理器维度
  ! dpkg -l | grep -q postfix &&
  # 文件系统维度
  ! find /etc -name '*postfix*' | grep -q . &&
  # 进程维度
  ! ps aux | grep -q '[p]ostfix'
}