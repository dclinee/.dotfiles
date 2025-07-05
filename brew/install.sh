# 使用国内镜像源安装（新增代码）
export HOMEBREW_INSTALL_FROM_API=1
init_brew_mirrors() {
  export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
  export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
}

# 问题：缺少镜像源可用性校验
# 带网络诊断的安装流程
if ! ping -c 1 mirrors.tuna.tsinghua.edu.cn &> /dev/null; then
  echo "\u001b[31m[ERROR] 网络不可达，请检查网络连接\u001b[0m"
  exit 1
fi

# 新增镜像源健康检查（第3-7行）
check_mirror() {
  # 修改镜像检查逻辑（第5行）
  curl -k --connect-timeout 5 -sI $1 || return 1
  
  # 修改证书安装逻辑（第9-13行）
  export DEBIAN_FRONTEND=noninteractive
  sudo apt-get update && sudo apt-get install --no-install-recommends -y \
      ca-certificates \
      openssl \
      && sudo update-ca-certificates --fresh \
      || echo "\u001b[33m[WARN] 证书更新部分失败\u001b[0m"
}

if ! check_mirror ${HOMEBREW_API_DOMAIN}; then
  echo "\u001b[33m[WARN] 切换备用镜像源\u001b[0m"
  export HOMEBREW_API_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles/api"
fi

# 自动安装Homebrew
if ! command -v brew &> /dev/null; then
  echo "\u001b[34m[INSTALL] 正在安装Homebrew...\u001b[0m"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  
  # 配置Linux环境变量
  if [[ "$(uname)" == "Linux" ]]; then
    echo "eval \"$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\"" >> ~/.zshrc
    if ! command -v brew &> /dev/null; then
      # Linux环境配置
      eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
  fi
fi

# 执行brew bundle
brew bundle --file="${BREWFILE}"

setup_brew_cache() {
  local cache_dir="${HOME}/.cache/homebrew"
  [ -d $cache_dir ] || mkdir -p $cache_dir
  export HOMEBREW_CACHE=$cache_dir
}


# 网络故障转移模块
check_network() {
  local retries=3 timeout=5
  while ((retries-- > 0)); do
    if curl -m $timeout -s https://mirrors.tuna.tsinghua.edu.cn >/dev/null; then
      return 0
    fi
    echo "\u001b[33m网络不可达，尝试备用镜像...\u001b[0m"
    sleep $((timeout *= 2))
  done
  return 1
}

# 在安装流程前调用
install_brew() {
  check_network || {
    echo "\u001b[31mERROR: 所有镜像源均不可用\u001b0m"
    return 1
  }
  # 原有安装逻辑...
}

MIRROR_LIST=(
  "https://mirrors.tuna.tsinghua.edu.cn"
  "https://mirrors.aliyun.com"
  "https://mirror.sjtu.edu.cn"
)

check_mirror_health() {
  for mirror in ${MIRROR_LIST[@]}; do
    if curl -m 3 -s ${mirror}/healthz | grep -q 'OK'; then
      export ACTIVE_MIRROR=${mirror}
      return 0
    fi
  done
  return 1
}

# 日志系统初始化
init_logger() {
  local log_dir
  export LOG_FILE="/tmp/brew-install-$(date +%Y%m%d).log"
  
  # 原子化文件锁
  if [[ -f "${LOG_FILE}.lock" ]]; then
    echo -e "\e[33m[WARN] 检测到已有安装进程（PID: $(cat ${LOG_FILE}.lock)）\e[0m"
    exit 1
  fi
  
  # 智能路径回退
  log_dir="${HOME}/.cache/brew-install"
  mkdir -p "$log_dir" || {
    echo -e "\e[31m[ERROR] 无法创建日志目录 ${log_dir}\e[0m"
    exit 1
  }
  
  # 日志轮转机制
  find "$(dirname "$LOG_FILE")" -name '*.log' -mtime +7 -delete
  
  exec &> >(tee -a "$LOG_FILE")
  trap 'rm -f "${LOG_FILE}.lock"' EXIT
  echo -e "[$(date +%FT%T)] 日志系统初始化完成（路径: \e[34m${LOG_FILE}\e[0m）"
}

# 在main函数开头调用
main() {
  init_logger
  echo "安装日志: $LOG_FILE"
  # 后续流程...
}