#!/usr/bin/env zsh

# ======================
# macOS 专用配置
# ======================

# macOS 专用别名
alias showfiles='defaults write com.apple.finder AppleShowAllFiles YES; killall Finder'
alias hidefiles='defaults write com.apple.finder AppleShowAllFiles NO; killall Finder'

# 使用 GNU 工具替代 BSD 工具
if command -v gsed > /dev/null; then
  alias sed='gsed'
fi
if command -v ggrep > /dev/null; then
  alias grep='ggrep'
fi

# iTerm2 集成
if [[ -f "${HOME}/.iterm2_shell_integration.zsh" ]]; then
  source "${HOME}/.iterm2_shell_integration.zsh"
fi
