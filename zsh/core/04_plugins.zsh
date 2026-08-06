#!/usr/bin/env zsh

# ======================
# 插件管理（使用 zinit）
# ======================
#
# 工作流程:
# 1. 初始化 zinit
# 2. 加载核心插件（自动补全、Git 增强、搜索等）
# 3. 懒加载非核心插件（fzf-tab、zsh-syntax-highlighting）
#
# 调试: ZSH_DEBUG_PLUGINS=1 zsh 可查看详细加载日志
# 禁用: ZSH_DISABLE_PLUGINS=1 跳过所有插件

# 支持 ZSH_DISABLE_PLUGINS=1 跳过所有插件
if [[ "${ZSH_DISABLE_PLUGINS:-0}" == "1" ]]; then
  return 0
fi

# zinit 初始化
# zinit 是 zsh 库，需要 source zinit.zsh 才能使用

# 调试日志（提前定义，供初始化使用）
_plugins_debug() {
  if [[ "${ZSH_DEBUG_PLUGINS:-0}" == "1" ]]; then
    echo -e "\033[36m[PLUGIN DEBUG]\033[0m $*" >&2
  fi
}

_zinit_init() {
  local zinit_zsh=""

  # 查找 zinit.zsh 安装路径（固定路径优先，brew 查询作为 fallback）
  local candidates=(
    # Homebrew 常见固定路径
    "/home/linuxbrew/.linuxbrew/opt/zinit/zinit.zsh"
    "/opt/homebrew/opt/zinit/zinit.zsh"
    "/usr/local/opt/zinit/zinit.zsh"
    # 手动 git clone 安装路径
    "${HOME}/.zinit/zinit.zsh"
    "${HOME}/.zinit-git/zinit.zsh"
    # 系统路径
    "/usr/share/zinit/zinit.zsh"
    "/usr/local/share/zinit/zinit.zsh"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -f "${candidate}" ]]; then
      zinit_zsh="${candidate}"
      break
    fi
  done

  # Fallback: 通过 brew 查询路径
  if [[ -z "${zinit_zsh}" ]] && command -v brew > /dev/null 2>&1; then
    local brew_zinit_path="$(brew --prefix zinit 2>/dev/null)/zinit.zsh"
    if [[ -f "${brew_zinit_path}" ]]; then
      zinit_zsh="${brew_zinit_path}"
    fi
  fi

  if [[ -z "${zinit_zsh}" ]]; then
    echo -e "\033[33m[WARN]\033[0m zinit 未安装，跳过插件加载" >&2
    echo -e "\033[33m[INFO]\033[0m 安装方式: brew install zinit" >&2
    echo -e "\033[33m[INFO]\033[0m 或: git clone https://github.com/zdharma-continuum/zinit.git ~/.zinit" >&2
    return 1
  fi

  _plugins_debug "加载 zinit: ${zinit_zsh}"
  source "${zinit_zsh}" 2>/dev/null
  return $?
}

if ! _zinit_init; then
  return 0
fi

_plugins_debug "zinit 已就绪，开始加载插件..."

# ======================
# 核心插件（同步加载，确保基础功能）
# ======================

# 自动补全建议（核心功能，同步加载）
zinit light zsh-users/zsh-autosuggestions

# 历史命令子串搜索（核心功能，同步加载）
zinit light zsh-users/zsh-history-substring-search

# ======================
# 懒加载插件（首次使用时才加载，节省启动时间）
# ======================

# forgit - Git 增强（首次使用 g/ga/gd 时加载）
zinit ice wait lucid
zinit light wfxr/forgit

# zsh-z - 智能目录跳转（首次使用 z 命令时加载）
# 注：zoxide 已提供相同功能，zsh-z 作为 fallback
zinit ice wait lucid
zinit light agkozak/zsh-z

# fzf-tab - Tab 补全增强（首次触发 Tab 补全时加载）
zinit ice wait lucid
zinit light Aloxaf/fzf-tab

# zsh-syntax-highlighting - 语法高亮（必须最后加载，首次键入时激活）
zinit ice wait lucid
zinit light zsh-users/zsh-syntax-highlighting

_plugins_debug "所有插件加载完成"

# ======================
# 插件管理辅助函数
# ======================

# 列出所有已加载插件
function list_plugins() {
  echo "zinit 已加载插件（含加载耗时）:"
  echo ""
  # 注: zinit v3.15+ 中 `loaded`/`list` 子命令解析有 bug，
  # 会把参数误认为 ice modifier。改用 `times` 显示插件+耗时。
  zinit times 2>/dev/null
  echo ""
  echo "可用命令: zinit help 查看所有命令"
  echo "  zinit times    - 插件加载耗时统计"
  echo "  zinit status   - 插件 git 状态"
  echo "  zbindkeys      - 列出快捷键绑定"
  echo "  zinit update   - 更新所有插件"
}

# 更新所有插件
function update_plugins() {
  echo "正在更新所有 zinit 插件..."
  zinit update
  echo "更新完成"
}

# 清理未使用的插件
function clean_plugins() {
  echo "正在清理 zinit 缓存..."
  zinit delete --all 2>/dev/null || echo "请手动使用 zinit delete <plugin> 删除不需要的插件"
  echo "提示: 可使用 zinit status 查看所有插件状态"
  echo "清理完成"
}
