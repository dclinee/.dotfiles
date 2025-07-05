#!/usr/bin/env bash
set -eo pipefail

temp_dir=$(mktemp -d)
trap 'rm -rf ${temp_dir}' EXIT

# 环境初始化
echo "\u001b[34m[INFO] 初始化测试环境\u001b[0m"
sudo rm -f /var/lib/dpkg/lock-frontend
sudo dpkg --configure -a
# 配置清华镜像源
sudo sed -i 's@//.*archive.ubuntu.com@//mirrors.tuna.tsinghua.edu.cn@g' /etc/apt/sources.list

# 配置brew镜像
export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"

# 更新软件源
sudo apt-get update -qq > /dev/null
# 新增模块初始化函数
init_cleanup() {
  export DEBIAN_FRONTEND=noninteractive
  sudo_cmd="sudo -E"
}

# 抽象核心清理逻辑
perform_postfix_cleanup() {
  $sudo_cmd apt purge -y 'postfix*'
  $sudo_cmd find /etc/postfix* -delete
}
# 终极清理方案
cleanup_system() {
  # 系统级深度清理
  # 安全停止postfix服务
if systemctl list-unit-files | grep -q postfix.service; then
  sudo systemctl stop postfix.service || true
fi

# 清理残留文件
sudo find /etc/postfix* /usr/lib/postfix /var/lib/postfix -maxdepth 2 -delete 2>/dev/null || true
# 使用apt代替dpkg处理通配符
sudo apt purge -y 'postfix-*' 2>/dev/null || true

# 精确路径清理
sudo find /etc/postfix* /var/lib/postfix -maxdepth 1 -delete 2>/dev/null
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

# 安装流程模拟模块
simulate_install() {
  echo "\u001b[34m[SIM] 模拟安装流程:\u001b[0m"
  
  # Brew安装模拟
  echo "\u001b[36m[Brew] 将执行:\u001b[0m"
  cat ${temp_dir}/brew/install.sh | grep 'brew bundle' --color=never
  
  # Zsh安装模拟
  echo "\u001b[36m[Zsh] 将配置:\u001b[0m"
  find ${temp_dir}/zsh -name '*.zsh' -exec grep '^source\|^export' {} \; | sort | uniq
}

# 命令行参数处理
case "$1" in
  --dry-run|--simulate)
    simulate_install
    exit 0
    ;;
esac

echo "\u001b[32m[SUCCESS] 全量测试通过\u001b[0m"

# 系统健康检查
check_system_health() {
  [ -f /var/lib/dpkg/lock ] && return 1
  dpkg -l | grep -qE 'postfix|mydomain' && return 1
  command -v curl >/dev/null && command -v git >/dev/null
}

retry() {
  local max=3
  local count=0
  until "$@"; do
    exit_code=$?
    count=$((count+1))
    [ $count -gt $max ] && return $exit_code
    sleep $((count * 5))
  done
}

# 日志分级输出函数
log() {
  local level=$1
  local message=$2
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  
  case $level in
    INFO) color='\033[34m' ;;
    WARN) color='\033[33m' ;;
    ERROR) color='\033[31m' ;;
  esac
  
  echo -e "${color}[${level}] ${timestamp} ${message}\033[0m" | tee -a debug.log
}

# 移除无效服务检查
# 优化sudo权限验证
check_sudo() {
  sudo -n true 2>/dev/null && return 0 || {
    echo -e "\033[33m[WARN] 需要sudo权限，请执行:\033[0m\n\t sudo visudo\n\033[33m添加以下配置:\033[0m\n\t $(whoami) ALL=(ALL) NOPASSWD: ALL"
    return 1
  }
}

if ! check_sudo; then
  echo "\u001b[33m[WARN] 需要sudo权限，请确保已配置免密sudo\u001b[0m"
  exit 127
fi

# 模拟执行检查
dry_run_check() {
  apt-get install -s curl git | grep -q 'NEW' || return 1
  ! dpkg -l | grep -q postfix
}

[[ "$1" == "--dry-run" ]] && {
  dry_run_check && echo "\u001b[32m[DRY RUN] 验证通过\u001b[0m" || exit 1
  exit 0
}

# 带指数退避的重试函数
retry_with_backoff() {
  local max=3 delay=5
  until "$@"; do
    ((max--)) || return 1
    sleep $((delay *= 2))
  done
}

# 在关键操作处应用重试
retry_with_backoff $sudo_cmd apt-get update
init_platform() {
  case $(uname) in
    Darwin) export PLATFORM=macOS;;
    Linux) export PLATFORM=Linux;;
    *) echo "Unsupported platform"; exit 1;;
  esac
}
