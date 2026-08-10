#!/usr/bin/env zsh
# Zsh 性能分析脚本
set -euo pipefail

echo "=== Zsh 启动时间分析 ==="
echo "冷启动（清除缓存后）:"
zsh -i -c "exit" 2>&1

echo ""
echo "使用 zprof 分析（需 zsh 5.9+）:"
if typeset -f zprof > /dev/null 2>&1 || autoload -U zprof 2>/dev/null; then
  zprof zsh -i -c "exit"
else
  echo "zprof 不可用，使用 time 替代:"
  echo "运行: time zsh -i -c 'exit'"
fi

echo ""
echo "=== 当前插件加载状态 ==="
if typeset -f list_plugins > /dev/null 2>&1; then
  list_plugins
else
  echo "已加载插件:"
  for p in ${(k)LOADED_PLUGINS}; do
    echo "  - $p"
  done
  echo "共 ${#LOADED_PLUGINS} 个插件已加载"
fi

echo ""
echo "提示: 使用 'zsh -xv' 可查看详细加载日志"
echo "      使用 'ZSH_DISABLE_PLUGINS=1 zsh' 可禁用所有插件测试纯启动时间"
echo "      使用 'ZSH_DEBUG_PLUGINS=1 zsh' 可查看插件加载调试信息"