#!/usr/bin/env zsh

# ======================
# 高效插件管理
# ======================

# 插件目录
PLUGIN_DIR="${ZSH_HOME}/plugins"
mkdir -p "${PLUGIN_DIR}"

# 高效加载插件函数
function load_plugin() {
  local plugin_name=$1
  local plugin_repo=$2
  local plugin_dir="${PLUGIN_DIR}/${plugin_name}"
  
  # 克隆插件（如果不存在）
  if [[ ! -d "${plugin_dir}" ]]; then
    git clone --depth 1 "${plugin_repo}" "${plugin_dir}" > /dev/null 2>&1
  fi
  
  # 尝试加载主要插件文件
  local init_files=(
    "${plugin_dir}/${plugin_name}.plugin.zsh"
    "${plugin_dir}/${plugin_name}.zsh"
    "${plugin_dir}/init.zsh"
    "${plugin_dir}/zsh-${plugin_name}.zsh"
  )
  
  # 尝试加载找到的第一个文件
  for init_file in "${init_files[@]}"; do
    if [[ -f "${init_file}" ]]; then
      source "${init_file}" > /dev/null 2>&1 && return 0
    fi
  done
  
  # 如果未找到特定文件，尝试加载目录中的第一个插件文件
  local first_plugin_file=$(find "${plugin_dir}" -maxdepth 1 -type f -name '*.zsh' | head -n 1)
  if [[ -f "${first_plugin_file}" ]]; then
    source "${first_plugin_file}" > /dev/null 2>&1 && return 0
  fi
  
  # 如果仍未加载，尝试加载目录中的所有 zsh 文件
  for file in "${plugin_dir}"/*.zsh; do
    [[ -f "$file" ]] && source "$file"
  done
}

# 插件更新函数
function update_plugins() {
  for dir in "${PLUGIN_DIR}"/*; do
    if [[ -d "${dir}/.git" ]]; then
      echo "Updating plugin: $(basename ${dir})"
      git -C "${dir}" pull --ff-only > /dev/null 2>&1
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
