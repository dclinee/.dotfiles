#!/usr/bin/env zsh

# ======================
# 高效插件管理
# ======================

# 插件目录
PLUGIN_DIR="${ZSH_HOME}/plugins"
mkdir -p "${PLUGIN_DIR}" 2>/dev/null

# 已加载插件跟踪数组
declare -A LOADED_PLUGINS

# 高效加载插件函数
function load_plugin() {
  local plugin_name=$1
  local plugin_repo=$2
  local plugin_dir="${PLUGIN_DIR}/${plugin_name}"
  
  # 检查插件是否已加载
  if [[ -n ${LOADED_PLUGINS[${plugin_name}]} ]]; then
    return 0
  fi
  
  # 带错误处理的克隆
  if [[ ! -d "${plugin_dir}" ]]; then
    mkdir -p "${plugin_dir}" && git clone "${plugin_repo}" "${plugin_dir}" 2>/dev/null || {
      echo "[31m[ERROR] Failed to clone plugin ${plugin_name} from ${plugin_repo}[0m" >&2
      return 1
    }
  fi

  # 版本锁定机制
  local lock_file="${plugin_dir}/.lock"
  if [[ -f "${lock_file}" ]]; then
    git -C "${plugin_dir}" checkout $(cat "${lock_file}") 2>/dev/null || {
      echo "[33m[WARN] Failed to checkout locked version for ${plugin_name}[0m" >&2
    }
  fi

  # 增强文件加载
  local init_files=(
    "${plugin_dir}/${plugin_name}.plugin.zsh"
    "${plugin_dir}/${plugin_name}.zsh"
    "${plugin_dir}/init.zsh"
    "${plugin_dir}"/zinit.zsh
  )
  
  for init_file in "${init_files[@]}"; do
    if [[ -f "${init_file}" ]]; then
      if ! source "${init_file}" 2>/dev/null; then
        echo "[33m[WARN] Failed to load ${init_file}[0m" >&2
      else
        LOADED_PLUGINS[${plugin_name}]=1
      fi
      break
    fi
  done
}

# 安全更新函数
function update_plugins() {
  for dir in "${PLUGIN_DIR}"/*; do
    if [[ -d "${dir}/.git" ]]; then
      git -C "${dir}" fetch --all 2>/dev/null && git -C "${dir}" reset --hard origin/HEAD 2>/dev/null || {
        echo "[33m[WARN] Failed to update plugin in ${dir}[0m" >&2
      }
    fi
  done
}

# ======================
# 加载核心插件
# ======================

# Zsh 自动建议
load_plugin "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions"

# Zsh 语法高亮
load_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting"

# 快速目录跳转
load_plugin "zoxide" "https://github.com/ajeetdsouza/zoxide"

# 模糊查找
load_plugin "fzf-tab" "https://github.com/Aloxaf/fzf-tab"

# Git 增强
load_plugin "forgit" "https://github.com/wfxr/forgit"

# 历史命令搜索
load_plugin "zsh-history-substring-search" "https://github.com/zsh-users/zsh-history-substring-search"

# 智能目录跳转
load_plugin "zsh-z" "https://github.com/agkozak/zsh-z"
