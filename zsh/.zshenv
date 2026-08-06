#!/usr/bin/env zsh

# ======================
# .zshenv - 最早加载的环境配置
# ======================
#
# 本文件在所有 zsh 会话中最先被加载（包括非交互式脚本）
# 仅放置必须最先初始化的环境变量
#
# 加载顺序：.zshenv → .zprofile → .zshrc（交互式）

# ZSH 配置根目录
export ZSH_HOME="${HOME}/.dotfiles/zsh"

# 确保 ~/.local/bin 在 PATH 中
if [[ -d "${HOME}/.local/bin" ]]; then
  case ":${PATH}:" in
    *":${HOME}/.local/bin:"*) ;;
    *) export PATH="${HOME}/.local/bin:${PATH}" ;;
  esac
fi

# Homebrew PATH 设置（根据系统）
if [[ "$(uname -s)" == "Linux" ]]; then
  if [[ -d "/home/linuxbrew/.linuxbrew/bin" ]]; then
    case ":${PATH}:" in
      *":/home/linuxbrew/.linuxbrew/bin:"*) ;;
      *) export PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}" ;;
    esac
    export HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
  fi
elif [[ "$(uname -s)" == "Darwin" ]]; then
  if [[ -d "/opt/homebrew/bin" ]]; then
    case ":${PATH}:" in
      *":/opt/homebrew/bin:"*) ;;
      *) export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:${PATH}" ;;
    esac
    export HOMEBREW_PREFIX="/opt/homebrew"
  elif [[ -d "/usr/local/bin" ]]; then
    case ":${PATH}:" in
      *":/usr/local/bin:"*) ;;
      *) export PATH="/usr/local/bin:/usr/local/sbin:${PATH}" ;;
    esac
    export HOMEBREW_PREFIX="/usr/local"
  fi
fi

# 防止重复加载（仅交互式 shell 处理后续配置）
[[ -o interactive ]] || return 0
