# 使用国内镜像源安装（新增代码）
export HOMEBREW_INSTALL_FROM_API=1
export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"

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

/bin/bash -c "$(curl -fsSL https://cdn.staticfile.org/Homebrew/install/HEAD/install.sh)"