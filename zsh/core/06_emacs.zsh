#!/usr/bin/env zsh

# ======================
# Emacs daemon 自动启动与管理
# ======================
#
# 功能:
#   - 交互式 zsh 启动时自动启动 emacs daemon（如未运行）
#   - 提供 emacs_daemon_start/stop/restart 管理函数
#   - 提供 ed/et 别名快速连接 daemon
#
# 禁用自动启动:
#   export EMACS_DAEMON_AUTOSTART=0

# 检查 emacs daemon 是否运行
_emacs_daemon_running() {
  command -v emacsclient >/dev/null 2>&1 || return 1
  emacsclient -e '(server-running-p)' 2>/dev/null | grep -q 't'
}

# 启动 emacs daemon
emacs_daemon_start() {
  if ! command -v emacs >/dev/null 2>&1; then
    echo "emacs 未安装" >&2
    return 1
  fi

  if _emacs_daemon_running; then
    echo "emacs daemon 已在运行"
    return 0
  fi

  echo "正在启动 emacs daemon..."
  # 后台异步启动并 disown，不阻塞 shell，不受 SIGHUP 影响
  (nohup emacs --daemon >/dev/null 2>&1 &!)
}

# 停止 emacs daemon
emacs_daemon_stop() {
  if _emacs_daemon_running; then
    emacsclient -e '(kill-emacs)' >/dev/null 2>&1
    echo "emacs daemon 已停止"
  else
    echo "emacs daemon 未运行"
  fi
}

# 重启 emacs daemon
emacs_daemon_restart() {
  emacs_daemon_stop
  sleep 1
  emacs_daemon_start
}

# 快捷连接 daemon
# ed: 图形界面 / et: 终端界面
alias ed='emacsclient -c -a ""'
alias et='emacsclient -t -a ""'

# 交互式 shell 启动时自动启动
if [[ -o interactive ]] && [[ "${EMACS_DAEMON_AUTOSTART:-1}" == "1" ]]; then
  if command -v emacs >/dev/null 2>&1 && ! _emacs_daemon_running; then
    (nohup emacs --daemon >/dev/null 2>&1 &!)
  fi
fi
