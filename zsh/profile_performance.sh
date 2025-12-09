#!/usr/bin/env zsh
# Zsh 性能分析脚本

echo "分析 Zsh 启动时间..."
zsh -i -c "exit" 2>&1 | head -20

echo -e "\n分析 Zsh 插件加载时间..."
zinit times
