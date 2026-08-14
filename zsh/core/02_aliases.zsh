#!/usr/bin/env zsh
# ======================
# 别名配置
# ======================

# ----------------------
# 1. 通用文件管理
# ----------------------
if (( $+commands[eza] )); then
  alias ls='eza --group-directories-first --icons'
  alias lt='eza --tree --level=2'
  alias lU='eza -la --sort=none'
  alias lM='eza -la --sort=modified'
elif [[ "$(uname)" == "Darwin" ]]; then
  # macOS BSD ls 不支持 --color=auto / --group-directories-first，用 -G 启用颜色
  alias ls='ls -G'
else
  alias ls='ls --color=auto --group-directories-first'
fi
alias ll='ls -l'             # 详细列表
alias la='ls -a'             # 显示隐藏文件
alias l='ls -la'             # 详细列表 + 隐藏文件
alias l.='ls -la .*'         # 只显示隐藏文件
alias lS='ls -laS'           # 按大小排序

# ----------------------
# 2. 导航别名
# ----------------------
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'
alias -- -='cd -'            # 快速返回上一个目录
alias cd..='cd ..'           # 容错，处理输入错误
alias dir='ls -la'

# ----------------------
# 3. 系统与工具别名
# ----------------------
if [[ "$(uname)" == "Darwin" ]]; then
  # macOS BSD grep 不支持 --color 参数，跳过
  # 如需颜色支持，建议: brew install grep 后使用 ggrep
  alias ggrep="$(brew --prefix grep 2>/dev/null || echo /usr/local)/bin/grep --color=auto" 2>/dev/null || true
else
  alias grep='grep --color=auto'
  alias egrep='egrep --color=auto'
  alias fgrep='fgrep --color=auto'
fi
alias df='df -h'             # 显示磁盘使用情况
alias du='du -h'             # 显示目录大小
alias du1='du -h --max-depth=1'  # 只显示一级目录大小
if command -v free > /dev/null 2>&1; then
  alias free='free -h'         # 显示内存使用情况
fi
alias psa='ps aux'           # 显示所有进程
alias pst='ps aux | grep -i'  # 搜索进程
if command -v htop > /dev/null 2>&1; then
  alias top='htop'             # 使用 htop 替代 top
fi
alias c='clear'
alias cls='clear'
alias q='exit'
alias h='history'

# ----------------------
# 4. 安全操作
# ----------------------
alias rm='rm -i'             # 删除前确认
alias cp='cp -i'             # 复制前确认
alias mv='mv -i'             # 移动前确认
alias mkdir='mkdir -p'       # 创建目录时自动创建父目录

# ----------------------
# 5. Git 别名
# ----------------------
alias g='git'
alias gs='git status'
alias ga='git add'
alias gaa='git add .'        # 添加所有文件
alias gc='git commit'
alias gcm='git commit -m'    # 带消息的提交
alias gcma='git commit -am'   # 添加并提交
alias gp='git push'
alias gpl='git pull'
alias gco='git checkout'
alias gcb='git checkout -b'  # 创建并切换分支
alias gcd='git checkout develop'
alias gcmain='git checkout main'
alias gd='git diff'
alias gds='git diff --stat'  # 只显示文件变更统计
alias gl='git log --oneline --graph'  # 简洁的日志
alias glo='git log --oneline'
alias gll='git log --oneline --graph --all'  # 显示所有分支日志
alias gbr='git branch'
alias gba='git branch -a'     # 显示所有分支
alias gbd='git branch -d'     # 删除分支
alias gfa='git fetch --all'   # 拉取所有远程分支
alias gsta='git stash'
alias gstp='git stash pop'

# ----------------------
# 6. 开发相关
# ----------------------
# Python（仅在非虚拟环境中设置别名，避免绕过 venv 的 python/pip）
if [[ -z "${VIRTUAL_ENV:-}" ]]; then
  alias python='python3'
  alias py='python3'
  alias pip='pip3'
fi
alias venv='python -m venv venv'
alias venva='source venv/bin/activate'  # 激活虚拟环境

# Node.js
alias npmr='npm run'
alias n='npm'
alias nr='npm run'
alias y='yarn'
alias yr='yarn run'
alias pn='pnpm'
alias pnr='pnpm run'

# ----------------------
# 7. Docker 相关
# ----------------------
alias d='docker'
alias dc='docker-compose'
alias dcb='docker-compose build'
alias dcu='docker-compose up'
alias dcd='docker-compose down'
alias dcl='docker-compose logs'
alias dps='docker ps'
alias di='docker images'
alias dk='docker kill'
alias drm='docker rm'
alias drmi='docker rmi'
alias dnet='docker network'
alias dv='docker volume'

# ----------------------
# 8. 网络相关
# ----------------------
alias ping='ping -c 5'        # 只发送5个包
alias fastping='ping -c 100 -i 0.2'
alias ip='ip -c'
if command -v ip > /dev/null 2>&1; then
  alias ifconfig='ip addr show'
fi
if command -v ss > /dev/null 2>&1; then
  alias netstat='ss -tuln'      # 替代 netstat
fi
# alias ss='ss -tuln'  # 已移除: 避免覆盖系统 ss 命令
alias wget='wget -c'         # 断点续传
alias curlL='curl -L'        # 跟随重定向（不覆盖默认 curl，避免破坏 API 调用）

# ----------------------
# 9. 压缩与解压
# ----------------------
alias untar='tar -xvf'
alias unzip='unzip'
alias zip='zip -r'
alias tgz='tar -czvf'
alias tbz2='tar -cjvf'
alias txz='tar -cJvf'

# ----------------------
# 10. 其他实用别名
# ----------------------
alias nano='nano -w'         # 禁用自动换行
# 注: 已移除 alias which='which -a'，因为 zsh 中 which 是 builtin，alias 会失效或行为异常
# 如需显示所有匹配，请用 whence -p 或 type -a
alias path='printf "%s\n" ${PATH//:/ }'  # 分行显示 PATH（用 printf 替代 echo -e）
kb() { echo $((1024 * ${1:-0})) }  # 快速计算字节大小
if command -v md5sum > /dev/null 2>&1; then
  alias md5='md5sum'
fi
if command -v sha256sum > /dev/null 2>&1; then
  alias sha256='sha256sum'
fi
# 注: 已移除 alias sum='sum -s'，覆盖了系统 sum 命令
# 如需 checksum，请用 md5/sha256 alias 或直接调用原命令
alias b='bc -l'              # 启动计算器

# ----------------------
# 11. Zsh 特定别名
# ----------------------
alias zshrc='${EDITOR:-vi} ~/.zshrc'  # 快速编辑 zshrc
alias zshenv='${EDITOR:-vi} ~/.zshenv'
alias zlogin='${EDITOR:-vi} ~/.zlogin'
alias zlogout='${EDITOR:-vi} ~/.zlogout'
alias reload='source ~/.zshrc'     # 重新加载 zshrc

# ----------------------
# 12. Brew 相关
# ----------------------
alias br='brew'                # brew 简写
alias ba='brew analytics'
alias bac='brew autoremove'     # 自动移除无用依赖
alias bcl='brew cleanup'        # 清理旧版本和缓存
alias bcln='brew cleanup -n'    # 预览清理内容
alias bd='brew doctor'          # 检查 brew 健康状态
alias be='brew edit'            # 编辑 formula
alias bf='brew formula'         # 显示 formula 路径
alias bi='brew install'         # 安装包
alias binf='brew info'          # 显示包信息
alias bl='brew list'            # 列出已安装的包
alias blo='brew list --outdated' # 列出过时的包
alias bmig='brew migrate'       # 迁移包到新位置
alias bo='brew outdated'        # 检查过时的包
alias bq='brew query'           # 搜索包
alias brr='brew reinstall'       # 重新安装包
alias bs='brew search'          # 搜索包
alias bsf='brew search --formula' # 只搜索 formula
alias bsci='brew search --casks' # 只搜索 casks
alias bsw='brew search --desc'  # 按描述搜索
alias bsl='brew services list'  # 列出 brew 服务
alias bss='brew services start' # 启动 brew 服务
alias bsp='brew services stop'  # 停止 brew 服务
alias bsr='brew services restart' # 重启 brew 服务
alias bswt='brew switch'        # 切换包版本
alias bu='brew update'          # 更新 brew 和包列表
alias bup='brew upgrade'        # 升级所有过时的包
alias buu='brew update && brew upgrade'  # 更新并升级所有包
alias bupn='brew upgrade --dry-run' # 预览升级内容
alias bupc='brew upgrade --cask' # 升级所有 casks
alias bv='brew --version'       # 显示 brew 版本

# Brew Bundle 相关
alias bba='brew bundle'         # 运行 Brewfile
alias bbc='brew bundle cleanup'  # 清理 Brewfile 中未列出的包
alias bbd='brew bundle dump'     # 生成 Brewfile
alias bbl='brew bundle list'    # 列出 Brewfile 中的包
alias bbv='brew bundle --verbose' # 详细输出

#-------------------------------------------------------------------------------------------------------
# Emacs 相关
# Emacs Daemon 核心别名
alias es="emacs --daemon"
alias ekill='emacsclient -e "(kill-emacs)"'

# 注意: 由于 setopt aliases 启用后 zsh 会在函数定义时展开 alias
# 函数体内禁止引用 alias 名称，也避免混合单双引号
# 使用变量传递命令以彻底规避解析器歧义
emacs_kill_cmd='emacsclient -e "(kill-emacs)"'
erestart() {
  eval "$emacs_kill_cmd" 2>/dev/null || true
  sleep 0.3 2>/dev/null || sleep 1
  command emacs --daemon
}

# GUI 客户端（日常主力）
alias e="emacsclient -c -n -a emacs"
alias ec="emacsclient -c -n -a emacs"
alias emg="emacsclient -c -n -a emacs"

# 终端内客户端（git/ssh服务器）
alias et="emacsclient -t -a emacs"
alias emt="emacsclient -t -a emacs"

# 独立进程（干净环境调试）
alias en="emacs -nw"
alias emnew="emacs"
alias emmini="emacs -q -nw"

# 配置快捷入口（适配你的dotfiles）
alias eminit="et ~/.config/emacs/init.el"
alias emearly="et ~/.config/emacs/early-init.el"
alias emlisp="et ~/.config/emacs/lisp/"
alias eminstall="et ~/.dotfiles/emacs/install.sh"
alias emlog="less /tmp/dotfiles_emacs_install_*.log"

# 默认编辑器（使用 emacsclient，若 emacs 未安装则 00_env.zsh 已设 nvim/vim）
# 仅在 emacs 已安装时覆盖 00_env.zsh 的设置
if command -v emacsclient > /dev/null 2>&1; then
  # 附加参数通过 .emacs 中的 ALTERNATE_EDITOR 变量传递
  export EDITOR="emacsclient"
  export VISUAL="emacsclient -c -n -a emacs"
fi

# 智能替换原生emacs命令
emacs() {
  if [[ -n "$DISPLAY" || "$TERM_PROGRAM" =~ "iTerm|WezTerm|Terminal" ]]; then
    emacsclient -c -n -a emacs "$@"
  else
    emacsclient -t -a emacs "$@"
  fi
}

# ----------------------
# 13. 平台特定别名在 platform/ 文件中定义
# ----------------------
