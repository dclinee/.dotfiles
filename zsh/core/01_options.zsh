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

# compinit 缓存优化
# 策略：
#   1. 若安装了 zsh-defer（zinit 或 brew install zsh-defer）
#      → defer 模式：首次补全触发时才 compinit，冷启动节省 ~150ms
#   2. 否则走传统 compinit：基于 mtime + -C/-s 缓存复用
ZSH_COMPDUMP="${HOME}/.cache/zsh/zcompdump"
mkdir -p "${HOME}/.cache/zsh" 2>/dev/null || true

# 自动探测 zsh-defer
#   可能位置: zinit 插件目录 / brew / /usr/share / 用户自装
_zsh_defer_source=""
for _d_src in \
  "${HOME}/.zinit/plugins/romkatv---zsh-defer/zsh-defer.plugin.zsh" \
  "${HOME}/.cache/zinit/plugins/romkatv---zsh-defer/zsh-defer.plugin.zsh" \
  "$(command -v brew > /dev/null 2>&1 && brew --prefix zsh-defer 2>/dev/null)/share/zsh/site-functions/zsh-defer" \
  "/usr/share/zsh-defer/zsh-defer.plugin.zsh" \
  "/usr/share/zsh/site-functions/zsh-defer" \
  "${DOTFILES_ROOT:-$HOME/.dotfiles}/zsh/plugins/zsh-defer/zsh-defer.plugin.zsh"
do
  [[ -n "${_d_src}" ]] && [[ -f "${_d_src}" ]] || continue
  _zsh_defer_source="${_d_src}"
  break
done
_unset_dummy() { unset _d_src; } 2>/dev/null
_unset_dummy

if [[ -n "${_zsh_defer_source}" ]]; then
  # ============================================================
  # 路径 A: zsh-defer 可用 → 延迟 compinit，冷启动最快路径
  # ============================================================
  # shellcheck source=/dev/null
  source "${_zsh_defer_source}"
  unset _zsh_defer_source

  _init_completion_deferred() {
    # 删除一次性钩子，避免重复调用
    precmd_functions=("${(@)precmd_functions:#_init_completion_deferred}")
    chpwd_functions=("${(@)chpwd_functions:#_init_completion_deferred}")

    # 真正的 compinit（在首次交互事件后，用户无感知延迟）
    if [[ ! -f "${ZSH_COMPDUMP}" ]]; then
      compinit -u -d "${ZSH_COMPDUMP}"
    else
      # 跳过安全检查，直接加载已有 dump（最快）
      compinit -C -d "${ZSH_COMPDUMP}" -s
    fi
  }

  # 注册到第一个 precmd 事件（用户看到提示符后触发）
  # 这样用户首次 Enter 前补全已就绪，体感无延迟
  precmd_functions=("${precmd_functions[@]}" _init_completion_deferred)

  # 防护：如果用户在首次 precmd 前按 Tab，兜底立即初始化
  zle -N _compdef_first_keypress _init_completion_deferred
  # 以下任一按键触发立即初始化：
  for _k in "^I" "^X^I"; do  # Tab, Ctrl-X Tab
    bindkey -M emacs "${_k}" "_generic_completion_init" 2>/dev/null || true
    bindkey -M vicmd "${_k}" "_generic_completion_init" 2>/dev/null || true
    bindkey -M viins "${_k}" "_generic_completion_init" 2>/dev/null || true
  done
  # 定义通用补全初始化 widget
  _generic_completion_init() {
    _init_completion_deferred 2>/dev/null || true
    # 委派给真实的补全
    if zle -l expand-or-complete > /dev/null 2>&1; then
      zle expand-or-complete
    else
      zle complete-word
    fi
  }
  zle -N _generic_completion_init 2>/dev/null || true
  unset _k
else
  unset _zsh_defer_source
  # ============================================================
  # 路径 B: 无 zsh-defer → 直接 compinit，但保持 mtime 缓存
  # ============================================================
  if [[ ! -f "${ZSH_COMPDUMP}" ]]; then
    # 首次启动或缓存被清理，完整重建
    compinit -u -d "${ZSH_COMPDUMP}"
  else
    # 缓存存在，使用 -C 跳过检查直接加载（最快路径）
    compinit -C -d "${ZSH_COMPDUMP}" -s
  fi
fi

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
# 历史文件fcntl锁（防止并发写入损坏）
setopt hist_fcntl_lock
# 历史文件保存时先复制再写入（兼容性）
setopt hist_save_by_copy

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
