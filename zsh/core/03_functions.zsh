#!/usr/bin/env zsh

# ======================
# 自定义函数
# ======================

# ----------------------
# 目录导航
# ----------------------

# 创建目录并进入
mkcd() { mkdir -p "$@" && cd "${@: -1}" || return; }

# 返回到上一个目录
back() {
  cd "-" || return
}

# 显示目录栈
cdls() {
  dirs -v
}

# ----------------------
# 文件操作
# ----------------------

# 快速备份文件
bak() { cp -v "$1"{,.bak}; }

# 恢复备份文件
restore() {
  if [ -f "$1.bak" ]; then
    cp -v "$1.bak" "$1"
  else
    echo "Backup not found: $1.bak"
  fi
}

# 提取各类压缩包
extract() {
  if [ -f "$1" ]; then
    case "$1" in
      *.tar.gz|*.tgz)    tar xvzf "$1" ;;
      *.tar.bz2|*.tbz2)  tar xvjf "$1" ;;
      *.tar.xz|*.txz)    tar xvJf "$1" ;;
      *.zip)             unzip "$1" ;;
      *.rar)             unrar x "$1" ;;
      *.7z)              7z x "$1" ;;
      *.bz2)             bunzip2 "$1" ;;
      *.gz)              gunzip "$1" ;;
      *.tar)             tar xvf "$1" ;;
      *.xz)              unxz "$1" ;;
      *.Z)               uncompress "$1" ;;
      *)                 echo "不支持的格式: $1" ;;
    esac
  else
    echo "文件不存在: $1"
  fi
}

# 创建压缩包
compress() {
  if [ -n "$1" ]; then
    case "$2" in
      tar.gz|tgz)   tar cvzf "$1.tar.gz" "${@:3}" ;;
      tar.bz2|tbz2) tar cvjf "$1.tar.bz2" "${@:3}" ;;
      tar.xz|txz)   tar cvJf "$1.tar.xz" "${@:3}" ;;
      zip)          zip -r "$1.zip" "${@:3}" ;;
      rar)          rar a "$1.rar" "${@:3}" ;;
      7z)           7z a "$1.7z" "${@:3}" ;;
      *)            echo "不支持的格式: $2" ;;
    esac
  else
    echo "用法: compress <名称> <格式> <文件/目录...>"
  fi
}

# 查找文件
findf() {
  find . -type f -name "*$1*" -print 2>/dev/null
}

# 查找目录
findd() {
  find . -type d -name "*$1*" -print 2>/dev/null
}

# 搜索文件内容
grepf() {
  grep -r "$1" --include="*.${2:-*}" . 2>/dev/null
}

# ----------------------
# 系统信息
# ----------------------

# 显示系统信息
info() {
  echo "=== 系统信息 ==="
  uname -a
  echo
  echo "=== CPU 信息 ==="
  lscpu | head -20
  echo
  echo "=== 内存信息 ==="
  free -h
  echo
  echo "=== 磁盘信息 ==="
  df -h
  echo
  echo "=== 网络信息 ==="
  ip addr | grep inet
}

# 显示磁盘使用情况
disk() {
  df -h | grep -v tmpfs
}

# 显示内存使用情况
mem() {
  free -h
}

# 显示CPU使用率
cpu() {
  top -bn1 | grep "%Cpu"
}

# ----------------------
# 网络功能
# ----------------------

# 快速查看公网IP
publicip() {
  curl -s https://api.ip.sb/jsonip
}

# 测试网络延迟
pingg() {
  ping -c 5 "${1:-baidu.com}"
}

# 快速启动本地HTTP服务器
serve() {
  local port="${1:-8000}"
  echo "启动HTTP服务器在端口 $port..."
  echo "访问地址: http://localhost:$port"
  python3 -m http.server "$port"
}

# ----------------------
# Git 操作
# ----------------------

# 创建新目录并初始化为 Git 仓库
git-init() {
  mkdir "$1" && cd "$1"
  git init
  touch README.md
  git add README.md
  git commit -m "Initial commit"
}

# 快速提交
git-commit() {
  git add .
  git commit -m "${1:-Update}"
}

# 显示Git状态
git-status() {
  git status
}

# 显示Git日志
git-log() {
  git log --oneline --graph --decorate --all
}

# 显示Git分支
git-branch() {
  git branch -a
}

# 快速推送
git-push() {
  git push origin "$(git rev-parse --abbrev-ref HEAD)"
}

# 快速拉取
git-pull() {
  git pull origin "$(git rev-parse --abbrev-ref HEAD)"
}

# ----------------------
# 开发工具
# ----------------------

# 查找进程
psg() {
  ps aux | grep -v grep | grep -i "$1"
}

# 杀死进程
killp() {
  ps aux | grep -i "$1" | grep -v grep | awk '{print $2}' | xargs kill -9
}

# 显示环境变量
env() {
  if [ -n "$1" ]; then
    echo "${(P)1}"
  else
    printenv | sort
  fi
}

# 快速编辑Zsh配置
ezd() {
  ${EDITOR:-vim} "${HOME}/.dotfiles/zsh/.zshrc"
}

# 重新加载Zsh配置
reload-zsh() {
  source "${HOME}/.zshrc"
  echo "Zsh配置已重新加载"
}

# ----------------------
# 其他功能
# ----------------------

# 生成随机密码
passwdgen() {
  local length="${1:-16}"
  openssl rand -base64 "$length" | head -c "$length"
  echo
}

# 格式化JSON
json() {
  if [ -f "$1" ]; then
    cat "$1" | python3 -m json.tool
  else
    cat - | python3 -m json.tool
  fi
}

# 格式化YAML
yaml() {
  if [ -f "$1" ]; then
    python3 -c "import yaml, sys; print(yaml.dump(yaml.safe_load(open('$1')), default_flow_style=False))"
  else
    python3 -c "import yaml, sys; print(yaml.dump(yaml.safe_load(sys.stdin), default_flow_style=False))"
  fi
}

# 显示颜色测试
color_test() {
  for i in {0..255}; do
    printf "\e[38;5;${i}m%3d\e[0m " "$i"
    if (( (i + 1) % 16 == 0 )); then
      echo
    fi
  done
}

# 快速计算
calc() {
  python3 -c "print($*)"
}

# 显示天气信息
weather() {
  curl -s "https://wttr.in/${1:-beijing}?lang=zh"
}
