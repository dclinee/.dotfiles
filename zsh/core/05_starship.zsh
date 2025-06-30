#!/usr/bin/env zsh

# ======================
# Starship 提示符配置
# ======================

# 初始化 Starship
if command -v starship > /dev/null; then
  eval "$(starship init zsh)"
else
  # 如果 Starship 未安装，使用简单提示符
  PROMPT='%F{blue}%~%f %# '
  RPROMPT='%F{8}%*%f'
  
  # 提示用户安装 Starship
  echo "Starship not installed. Run: curl -sS https://starship.rs/install.sh | sh"
fi
