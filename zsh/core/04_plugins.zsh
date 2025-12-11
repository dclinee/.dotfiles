#!/usr/bin/env zsh

# ======================
# 高效插件管理
# ======================

# 插件目录
PLUGIN_DIR="${ZSH_HOME}/plugins"
mkdir -p "${PLUGIN_DIR}" 2>/dev/null

# 初始化 zinit 插件管理器
ZINIT_DIR="${PLUGIN_DIR}/zinit"
if [ -f "${ZINIT_DIR}/zinit.zsh" ]; then
  # 初始化 zinit - zinit 会自动检测其主目录
  source "${ZINIT_DIR}/zinit.zsh"
  
  # 显式更新 ZINIT[HOME_DIR] 为我们的自定义目录
  ZINIT[HOME_DIR]="${ZINIT_DIR}"
  
  # 确保完成文件目录存在
  mkdir -p "${ZINIT[COMPLETIONS_DIR]}" 2>/dev/null
  
  # 手动创建 zinit 完成文件链接
  if [ -f "${ZINIT_DIR}/_zinit" ] && [ ! -f "${ZINIT[COMPLETIONS_DIR]}/_zinit" ]; then
    ln -sf "${ZINIT_DIR}/_zinit" "${ZINIT[COMPLETIONS_DIR]}/_zinit"
  fi
fi

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

  # 增强文件加载 - 完善初始化文件列表
  local init_files=(
    "${plugin_dir}/${plugin_name}.plugin.zsh"
    "${plugin_dir}/${plugin_name}.zsh"
    "${plugin_dir}/init.zsh"
  )
  
  # 处理特殊情况：zsh-syntax-highlighting 插件
  if [[ "${plugin_name}" == "zsh-syntax-highlighting" ]]; then
    init_files+=("${plugin_dir}/zsh-syntax-highlighting.zsh")
  fi
  
  # 安全添加匹配的 plugin.zsh 文件，避免 no match 错误
  local plugin_files=("${plugin_dir}"/*.plugin.zsh(N))
  if [[ ${#plugin_files[@]} -gt 0 ]]; then
    init_files+=(${plugin_files[@]})
  fi
  
  # 安全添加匹配的 zsh 文件，避免 no match 错误
  local zsh_files=("${plugin_dir}"/*.zsh(N))
  if [[ ${#zsh_files[@]} -gt 0 ]]; then
    init_files+=(${zsh_files[@]})
  fi
  
  local loaded=false
  for init_file in "${init_files[@]}"; do
    if [[ -f "${init_file}" ]]; then
      if source "${init_file}" 2>/dev/null; then
        LOADED_PLUGINS[${plugin_name}]=1
        loaded=true
      else
        echo "[33m[WARN] Failed to load ${init_file}[0m" >&2
      fi
      break
    fi
  done
  
  # 特殊处理 zsh-syntax-highlighting 插件
  if [[ "${plugin_name}" == "zsh-syntax-highlighting" ]] && ! $loaded; then
    local syntax_file="${plugin_dir}/zsh-syntax-highlighting.zsh"
    if [[ -f "${syntax_file}" ]]; then
      if source "${syntax_file}" 2>/dev/null; then
        LOADED_PLUGINS[${plugin_name}]=1
        loaded=true
      else
        echo "[33m[WARN] Failed to load zsh-syntax-highlighting from ${syntax_file}[0m" >&2
      fi
    fi
  fi
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

# Zsh 语法高亮 - 必须在最后加载
load_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting"
