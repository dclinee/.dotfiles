#!/usr/bin/env zsh

# ======================
# 别名配置
# ======================

# ----------------------
# 1. 通用文件管理
# ----------------------
if (( $+commands[eza] )); then
  alias ls='eza --group-directories-first --icons'
elif [[ "$(uname)" == "Darwin" ]]; then
  # macOS BSD ls 不支持 --color=auto / --group-directories-first，用 -G 启用颜色
  alias ls='ls -G'
else
  alias ls='ls --color=auto --group-directories-first'
fi
alias ll='ls -l'             # 详细列表
alias la='ls -a'             # 显示隐藏文件
alias lt='ls -T'             # 树形结构
alias l='ls -la'             # 详细列表 + 隐藏文件
alias l.='ls -la .*'         # 只显示隐藏文件
alias lS='ls -laS'           # 按大小排序
alias lU='ls -laU'           # 按访问时间排序
alias lM='ls -laM'           # 按修改时间排序

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
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
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
# Python
alias python='python3'
alias py='python3'
alias pip='pip3'
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
alias fastping='ping -c 100 -s.2'
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
alias 1024='echo $((1024*$1))'  # 快速计算字节大小
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
alias zshrc='${EDITOR} ~/.zshrc'  # 快速编辑 zshrc
alias zshenv='${EDITOR} ~/.zshenv'
alias zlogin='${EDITOR} ~/.zlogin'
alias zlogout='${EDITOR} ~/.zlogout'
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

# ----------------------
# 13. 平台特定别名在 platform/ 文件中定义
# ----------------------