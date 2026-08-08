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

# zoxide 懒加载（首次使用 z 命令时才初始化）
_zoxide_lazy_init() {
  local zoxide_init="${ZSH_HOME}/plugins/zoxide/init.zsh"
  if [[ -f "${zoxide_init}" ]]; then
    source "${zoxide_init}" 2>/dev/null
    hash -r
  fi
}

# zoxide 目录跳转（懒加载包装）
# 注意: 先移除可能存在的 alias 'z' 以避免与函数定义冲突
unalias z 2>/dev/null || true
z() {
  if ! command -v zoxide > /dev/null 2>&1; then
    echo "zoxide 未安装，请先安装: brew install zoxide"
    return 1
  fi
  _zoxide_lazy_init
  unfunction z
  z "$@"
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

# 提取各类压缩包 (带命令存在性检查)
extract() {
  if [ ! -f "$1" ]; then
    echo "文件不存在: $1"
    return 1
  fi
  case "$1" in
    *.tar.gz|*.tgz)    tar xvzf "$1" ;;
    *.tar.bz2|*.tbz2)  tar xvjf "$1" ;;
    *.tar.xz|*.txz)    tar xvJf "$1" ;;
    *.tar)             tar xvf "$1" ;;
    *.zip)
      command -v unzip > /dev/null 2>&1 && unzip "$1" || echo "未安装 unzip" ;;
    *.rar)
      command -v unrar > /dev/null 2>&1 && unrar x "$1" || echo "未安装 unrar" ;;
    *.7z)
      command -v 7z > /dev/null 2>&1 && 7z x "$1" || echo "未安装 7z" ;;
    *.bz2)
      command -v bunzip2 > /dev/null 2>&1 && bunzip2 "$1" || echo "未安装 bunzip2" ;;
    *.gz)
      command -v gunzip > /dev/null 2>&1 && gunzip "$1" || echo "未安装 gunzip" ;;
    *.xz)
      command -v unxz > /dev/null 2>&1 && unxz "$1" || echo "未安装 unxz" ;;
    *.Z)
      command -v uncompress > /dev/null 2>&1 && uncompress "$1" || echo "未安装 uncompress" ;;
    *)                 echo "不支持的格式: $1" ;;
  esac
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
# 系统信息（跨平台）
# ----------------------

# 显示系统信息
info() {
  echo "=== 系统信息 ==="
  uname -a
  echo
  echo "=== CPU 信息 ==="
  if command -v lscpu > /dev/null 2>&1; then
    lscpu | head -20
  elif command -v sysctl > /dev/null 2>&1; then
    sysctl -n machdep.cpu.brand_string 2>/dev/null || sysctl -a 2>/dev/null | head -20
  fi
  echo
  echo "=== 内存信息 ==="
  if command -v free > /dev/null 2>&1; then
    free -h
  elif command -v vm_stat > /dev/null 2>&1; then
    vm_stat
  fi
  echo
  echo "=== 磁盘信息 ==="
  df -h
  echo
  echo "=== 网络信息 ==="
  if command -v ip > /dev/null 2>&1; then
    ip addr | grep inet
  elif command -v ifconfig > /dev/null 2>&1; then
    ifconfig 2>/dev/null | grep "inet "
  fi
}

# 显示磁盘使用情况
disk() {
  df -h | grep -v tmpfs
}

# 显示内存使用情况
mem() {
  if command -v free > /dev/null 2>&1; then
    free -h
  elif command -v vm_stat > /dev/null 2>&1; then
    vm_stat
  else
    echo "无法获取内存信息"
  fi
}

# 显示CPU使用率
cpu() {
  if command -v top > /dev/null 2>&1; then
    top -bn1 2>/dev/null | grep "%Cpu" || top -l 1 -n 0 2>/dev/null | grep "CPU"
  fi
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

# 杀死进程（带确认）
killp() {
  local pids
  pids=$(ps aux | grep -i "$1" | grep -v grep | awk '{print $2}')
  if [[ -z "$pids" ]]; then
    echo "未找到匹配进程: $1"
    return 1
  fi
  echo "将杀死以下进程:"
  echo "$pids"
  echo -n "确认? (y/N): "
  read -r confirm
  if [[ "$confirm" == "y" ]]; then
    echo "$pids" | xargs kill -9
    echo "已发送 SIGKILL"
  else
    echo "已取消"
  fi
}

# 显示环境变量 (不覆盖系统 env 命令)
showenv() {
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
  if [ -n "$1" ] && [ -f "$1" ]; then
    python3 -m json.tool < "$1"
  else
    python3 -m json.tool
  fi
}

# 格式化YAML (安全版: 参数传递防止注入)
yaml() {
  if [ -n "$1" ] && [ -f "$1" ]; then
    python3 -c "import yaml, sys; print(yaml.dump(yaml.safe_load(open(sys.argv[1])), default_flow_style=False))" "$1"
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

# 快速计算 (安全版: 参数传递防止代码注入)
calc() {
  python3 -c "import sys; print(eval(sys.argv[1]))" "$*"
}

# 显示天气信息
weather() {
  curl -s "https://wttr.in/${1:-beijing}?lang=zh"
}

# ----------------------
# 环境诊断
# ----------------------

# 显示完整环境诊断信息
check_env() {
  echo "=== 环境诊断 ==="
  echo ""

  # 系统信息
  echo "--- 系统信息 ---"
  echo "操作系统: $(uname -s) $(uname -m)"
  echo "Zsh 版本: $(zsh --version | head -1)"
  echo "Shell: ${SHELL:-unknown}"
  echo "当前用户: $(whoami)"
  echo ""

  # Homebrew 状态
  echo "--- Homebrew ---"
  if command -v brew > /dev/null 2>&1; then
    echo "✅ Homebrew: $(command -v brew)"
    echo "   版本: $(brew --version 2>/dev/null | head -1 || echo '未知')"
    echo "   前缀: ${HOMEBREW_PREFIX:-$(brew --prefix 2>/dev/null || echo '未知')}"
  else
    echo "❌ Homebrew: 未安装"
  fi
  echo ""

  # 核心工具
  echo "--- 核心工具 ---"
  local tools=(git python3 node curl wget starship eza zoxide)
  for tool in "${tools[@]}"; do
    if command -v "$tool" > /dev/null 2>&1; then
      echo "✅ $tool: $(command -v "$tool")"
    else
      echo "❌ $tool: 未安装"
    fi
  done
  echo ""

  # 编辑器
  echo "--- 编辑器 ---"
  echo "默认编辑器: ${EDITOR:-未设置}"
  echo "VISUAL: ${VISUAL:-未设置}"
  echo ""

  # 插件状态
  echo "--- 插件管理器 ---"
  if command -v zinit > /dev/null 2>&1 || [[ -f "${HOME}/.zinit/zinit.zsh" ]] || [[ -f "$(brew --prefix zinit 2>/dev/null)/zinit.zsh" ]]; then
    echo "✅ zinit: 已安装"
  else
    echo "⚠️  zinit: 未安装 (插件可能无法加载)"
  fi
  echo ""

  # Nerd Font 检测
  echo "--- 字体检测 ---"
  if [[ -n "${STARSHIP_CONFIG:-}" ]] && [[ "$(basename "${STARSHIP_CONFIG}")" == "starship.toml" ]]; then
    echo "✅ Nerd Font: 已检测 (使用完整图标)"
  elif [[ -n "${STARSHIP_CONFIG:-}" ]] && [[ "$(basename "${STARSHIP_CONFIG}")" == "starship_fallback.toml" ]]; then
    echo "⚠️  Nerd Font: 未检测 (使用降级符号)"
    echo "   安装方式:"
    echo "     cd ~/.dotfiles && ./zsh/install.sh  # 自动安装"
    echo "     或手动: https://www.nerdfonts.com/font-downloads"
    echo "   安装后请在终端设置中选择 Nerd Font 字体"
  else
    echo "❌ Starship: 未配置"
  fi
  echo ""

  # PATH 信息
  echo "--- PATH ---"
  echo "当前 PATH:"
  echo "$PATH" | tr ':' '\n' | while read -r path; do
    if [[ -d "$path" ]]; then
      echo "  ✅ $path"
    else
      echo "  ⚠️  $path (不存在)"
    fi
  done
  echo ""

  echo "诊断完成！"
}

# 检查依赖是否齐全
check_dependencies() {
  local missing=()
  local optional=()

  echo "=== 依赖检查 ==="
  echo ""

  # 必需依赖
  local required=(brew git zsh)
  echo "--- 必需依赖 ---"
  for cmd in "${required[@]}"; do
    if command -v "$cmd" > /dev/null 2>&1; then
      echo "✅ $cmd: 已安装"
    else
      missing+=("$cmd")
      echo "❌ $cmd: 未安装"
    fi
  done
  echo ""

  # 推荐依赖
  echo "--- 推荐依赖 ---"
  local recommended=(starship eza zoxide fzf ripgrep bat)
  for cmd in "${recommended[@]}"; do
    if command -v "$cmd" > /dev/null 2>&1; then
      echo "✅ $cmd: 已安装"
    else
      optional+=("$cmd")
      echo "⚠️  $cmd: 未安装 (推荐安装)"
    fi
  done
  echo ""

  # 汇总
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "❌ 缺少 ${#missing[@]} 个必需依赖: ${missing[*]}"
    return 1
  else
    echo "✅ 所有必需依赖已安装"
  fi

  if [[ ${#optional[@]} -gt 0 ]]; then
    echo "💡 ${#optional[@]} 个推荐依赖未安装: ${optional[*]}"
    echo "   安装方式: brew install ${optional[*]}"
  fi

  return 0
}
