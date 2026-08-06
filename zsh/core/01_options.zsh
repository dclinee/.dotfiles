#!/usr/bin/env zsh

# ======================
# Zsh 选项配置
# ======================

# 自动补全配置
autoload -Uz compinit

# 补全菜单风格
zstyle ':completion:*' menu select
# 补全匹配规则（忽略大小写）
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
# 补全分组显示
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '[%d]'
# 补全描述
zstyle ':completion:*:options' description 'yes'
zstyle ':completion:*:options' auto-description '%d'
# 补全缓存 - 每天检查一次
local _today=$(date +'%Y-%m-%d')
local _compdump_date=""
if [[ -f "${HOME}/.cache/zsh/zcompdump" ]]; then
  if [[ "$(uname)" == "Darwin" ]]; then
    _compdump_date=$(stat -f '%Sm' -t '%Y-%m-%d' "${HOME}/.cache/zsh/zcompdump" 2>/dev/null || echo "")
  else
    _compdump_date=$(date -d "@$(stat -c %Y "${HOME}/.cache/zsh/zcompdump" 2>/dev/null || echo 0)" +'%Y-%m-%d' 2>/dev/null || echo "")
  fi
fi
if [[ "$_today" != "$_compdump_date" ]]; then
  compinit -u -d "${HOME}/.cache/zsh/zcompdump"
else
  compinit -C -d "${HOME}/.cache/zsh/zcompdump"
fi
unset _today _compdump_date

# 历史记录配置
# 追加历史记录
setopt append_history
# 扩展历史记录格式（包含时间戳）
setopt extended_history
# 忽略重复的命令
setopt hist_ignore_dups
# 忽略以空格开头的命令
setopt hist_ignore_space
# 共享历史记录
setopt share_history
# 历史命令时间戳显示
setopt hist_expire_dups_first
# 历史命令编辑
setopt hist_verify
# 历史命令查找
setopt hist_find_no_dups
# 历史命令减少空白
setopt hist_reduce_blanks
# 历史命令保存时添加时间戳
setopt hist_save_no_dups

# 文件匹配和扩展选项
# 启用隐藏文件匹配
setopt globdots
# 启用递归匹配
setopt extended_glob
# 启用大小写不敏感匹配
setopt nocaseglob
# 禁用通配符匹配失败时的错误
setopt nonomatch
# 启用文件名生成
setopt glob

# 命令执行选项
# 自动纠正命令错误
setopt correct
# 自动纠正参数错误
# setopt correct_all  # 已移除: 过于激进，会纠正文件名
# 禁用蜂鸣声
setopt no_beep
# 禁用视觉蜂鸣声
setopt no_list_beep
# 允许在交互式命令行中使用注释
setopt interactive_comments

# 目录导航选项
# 自动切换目录（无需 cd）
setopt auto_cd
# 自动 pushd
setopt auto_pushd
# 忽略重复的目录
setopt pushd_ignore_dups
# 交换 pushd 和 pushd -n
setopt pushd_minus
# 目录栈显示格式
setopt pushd_silent

# 输入/输出选项
# 允许使用 ^D 退出 shell
setopt ignore_eof
# 允许使用 >! 和 >>! 强制覆盖文件
setopt no_clobber
# 允许在命令行中使用 ? 和 * 等通配符
setopt csh_null_glob
# 允许在命令行中使用 = 进行命令查找
setopt equals

# 其他优化选项
# 禁用终端挂起
setopt no_flow_control
# 启用别名扩展
setopt aliases
# 启用提示符扩展
setopt prompt_subst
# 启用括号扩展
setopt brace_ccl
# 启用排序时的数字排序
setopt numeric_glob_sort

# 补全优化
# 补全时显示隐藏文件
zstyle ':completion:*' file-patterns '*(D)' '*(D):hidden-files'
# 补全时使用 ls 的颜色
if [[ -n "$LS_COLORS" ]]; then
  zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
fi
# 补全时使用最近使用的文件
zstyle ':completion:*' recent-dirs-insert both
# 补全时使用缓存
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${HOME}/.cache/zsh/compcache"

# 确保补全目录存在
[[ -d "${HOME}/.cache/zsh/compcache" ]] || mkdir -p "${HOME}/.cache/zsh/compcache" 2>/dev/null
