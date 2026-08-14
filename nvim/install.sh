#!/usr/bin/env bash
# ===================================
# Neovim AI 配置安装器
# ===================================
# 功能:
#   - 安装/更新 Neovim >= 0.9
#   - 链接配置文件到 ~/.config/nvim
#   - 可选: 安装 Ollama（本地 LLM）
#   - 可选: 安装 Copilot 插件

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$(dirname "$SCRIPT_DIR")" && pwd)"
NVIM_DIR="${DOTFILES_DIR}/nvim"
TARGET_DIR="${HOME}/.config/nvim"

# ===================================
# 输出函数
# ===================================
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
BOLD='\033[1m'
echo_title()  { echo -e "\n${BLUE}${BOLD}==> $*${NC}"; }
echo_step()   { echo -e "${GREEN}  →${NC} $*"; }
echo_warn()   { echo -e "${YELLOW}  ⚠${NC} $*"; }
echo_detail() { echo -e "    $*"; }

# ===================================
# 检测 Neovim
# ===================================
_check_nvim() {
  if command -v nvim &>/dev/null; then
    local nvim_version
    nvim_version=$(nvim --version | head -1 | grep -oP '\d+\.\d+' | head -1)
    echo_step "Neovim 已安装: v${nvim_version}"
    return 0
  fi
  echo_warn "Neovim 未安装"
  return 1
}

# ===================================
# 安装 Neovim
# ===================================
_install_nvim() {
  if _check_nvim; then return 0; fi

  echo_title "安装 Neovim"

  case "$(uname -s)" in
    Darwin)
      if command -v brew &>/dev/null; then
        brew install neovim
      else
        echo_warn "请先安装 Homebrew 或手动安装 Neovim"
        return 1
      fi
      ;;
    Linux)
      # 优先使用 AppImage（最新版）
      if command -v curl &>/dev/null; then
        local nvim_url="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.appimage"
        local nvim_bin="${HOME}/.local/bin/nvim"

        mkdir -p "${HOME}/.local/bin"
        echo_step "下载 Neovim AppImage..."
        curl -fLo "${nvim_bin}" --create-dirs --connect-timeout 10 --max-time 120 -sS "${nvim_url}" \
          || curl -fLo "${nvim_bin}" --create-dirs --connect-timeout 10 --max-time 120 -sS \
               "https://ghfast.top/${nvim_url}"

        chmod +x "${nvim_bin}"

        if command -v nvim &>/dev/null; then
          echo_step "Neovim 安装成功"
        else
          echo_warn "Neovim 安装失败，请手动安装"
          return 1
        fi
      else
        echo_warn "请安装 curl 后重试，或手动安装 Neovim"
        return 1
      fi
      ;;
    *)
      echo_warn "不支持的平台，请手动安装 Neovim: https://github.com/neovim/neovim"
      return 1
      ;;
  esac
}

# ===================================
# 链接配置
# ===================================
_link_config() {
  echo_title "链接 Neovim 配置"

  # 备份已有配置
  if [[ -e "${TARGET_DIR}" || -L "${TARGET_DIR}" ]]; then
    if [[ ! -L "${TARGET_DIR}" ]]; then
      local backup="${TARGET_DIR}.backup.$(date +%Y%m%d%H%M%S)"
      echo_step "备份已有配置: ${backup}"
      mv "${TARGET_DIR}" "${backup}"
    else
      rm -f "${TARGET_DIR}"
    fi
  fi

  # 确保父目录存在
  mkdir -p "$(dirname "${TARGET_DIR}")"

  # 创建符号链接
  ln -sf "${NVIM_DIR}" "${TARGET_DIR}"
  echo_step "已链接: ${NVIM_DIR} → ${TARGET_DIR}"
}

# ===================================
# 安装 Ollama（可选）
# ===================================
_install_ollama() {
  if command -v ollama &>/dev/null; then
    echo_step "Ollama 已安装"
    return 0
  fi

  echo_title "安装 Ollama（本地 LLM）"

  case "$(uname -s)" in
    Darwin)
      if command -v brew &>/dev/null; then
        brew install ollama
      fi
      ;;
    Linux)
      if command -v curl &>/dev/null; then
        curl -fsSL https://ollama.com/install.sh | sh
      fi
      ;;
  esac

  # 下载推荐模型
  if command -v ollama &>/dev/null; then
    echo_step "下载推荐模型..."
    ollama pull llama3.2 2>/dev/null || echo_warn "模型下载失败，可稍后手动: ollama pull llama3.2"
    ollama pull codellama:7b 2>/dev/null || echo_warn "模型下载失败，可稍后手动: ollama pull codellama:7b"
  fi
}

# ===================================
# 安装后提示
# ===================================
_post_install() {
  echo ""
  echo_title "Neovim AI 配置安装完成"

  echo ""
  echo -e "${BOLD}首次启动:${NC}"
  echo "  nvim 首次启动会自动安装 lazy.nvim 和所有插件"
  echo "  可能需要几分钟，请耐心等待"
  echo ""
  echo -e "${BOLD}AI 功能快捷键:${NC}"
  echo "  <leader>aa    AI 对话 (Copilot Chat)"
  echo "  <leader>ac    Continue AI 面板"
  echo "  <leader>cc    CodeCompanion 对话"
  echo "  <leader>ae    解释代码（选中后）"
  echo "  <leader>ar    代码审查（选中后）"
  echo "  <leader>af    修复代码（选中后）"
  echo "  <leader>ao    优化代码（选中后）"
  echo "  <leader>at    生成测试（选中后）"
  echo ""
  echo -e "${BOLD}AI 工具初始化:${NC}"
  echo "  Copilot:     :Copilot auth     (GitHub 认证)"
  echo "  Ollama:      ollama pull llama3.2  (下载模型)"
  echo "  Continue:    :Continue         (首次自动安装)"
  echo ""
  echo -e "${BOLD}文件位置:${NC}"
  echo "  配置:        ~/.config/nvim/init.lua"
  echo "  插件:        ~/.config/nvim/lua/plugins/"
  echo "  数据:        ~/.local/share/nvim/"
}

# ===================================
# 参数解析
# ===================================
INSTALL_OLLAMA=false
LINK_ONLY=false

show_help() {
  echo "用法: $0 [选项]"
  echo ""
  echo "选项:"
  echo "  --ollama      同时安装 Ollama 本地 LLM"
  echo "  --link-only   仅链接配置，不安装 Neovim"
  echo "  -h, --help    显示帮助"
}

for arg in "$@"; do
  case "$arg" in
    --ollama) INSTALL_OLLAMA=true ;;
    --link-only) LINK_ONLY=true ;;
    -h|--help) show_help; exit 0 ;;
  esac
done

# ===================================
# 主流程
# ===================================
main() {
  echo_title "Neovim AI 配置安装器"

  if [[ "${LINK_ONLY}" != "true" ]]; then
    _install_nvim
  fi

  _link_config

  if [[ "${INSTALL_OLLAMA}" == "true" ]]; then
    _install_ollama
  fi

  _post_install
}

main