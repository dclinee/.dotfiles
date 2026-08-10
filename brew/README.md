# Homebrew 模块

Homebrew 包管理配置，支持 Linux 和 macOS，使用 USTC 镜像加速。

## 文件结构

```
brew/
├── Brewfile             # 通用包（git、gh、fzf、ripgrep、bat、eza、zoxide 等）
├── Brewfile.linux       # Linux 特定包
├── Brewfile.macos       # macOS 特定包
├── install_brew.sh      # Homebrew 安装脚本（USTC 镜像）
└── .gitignore
```

## 快速使用

### 安装 Homebrew

```bash
# macOS / Linux（使用 USTC 镜像）
./brew/install_brew.sh
```

或使用官方安装：

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 安装 Brewfile 中的包

```bash
# 通过 Makefile
make brew

# 直接执行（会依次执行 Brewfile、Brewfile.linux/macos）
./bootstrap.sh --brew
```

**注意**：`brew bundle` 不支持嵌套 Brewfile，因此平台特定包需单独执行：

```bash
brew bundle --file=brew/Brewfile
brew bundle --file=brew/Brewfile.linux   # 或 Brewfile.macos
```

## Brewfile 内容

### 通用包（Brewfile）

| 包 | 说明 |
|---|---|
| `git` | 版本控制系统 |
| `gh` | GitHub CLI |
| `fzf` | 模糊查找 |
| `ripgrep` | 快速全文搜索 |
| `bat` | 语法高亮 cat |
| `eza` | ls 替代品 |
| `zoxide` | 智能 cd 替代品 |
| `fd` | find 替代品 |
| `jq` | JSON 处理 |
| `lazygit` | TUI Git 客户端 |
| `tree` | 目录树 |
| `watch` | 执行并观察 |

### Linux 特定（Brewfile.linux）

| 包 | 说明 |
|---|---|
| `node` | Node.js |
| `nvm` | Node 版本管理 |
| `python@3` | Python 3 |
| `rust` | Rust 编译器（如不使用 rustup） |
| `wezterm` | WezTerm 终端 |

### macOS 特定（Brewfile.macos）

| 包 | 说明 |
|---|---|
| `node` | Node.js |
| `python@3` | Python 3 |
| `wezterm` | WezTerm 终端 |
| `font-fira-code-nerd-font` | Nerd Font |
| `font-meslo-lg-nerd-font` | Nerd Font 备选 |

## 镜像源

安装脚本默认使用 **USTC 镜像**（mirrors.ustc.edu.cn），加速下载：

```bash
export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.ustc.edu.cn/brew.git"
export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.ustc.edu.cn/homebrew-core.git"
export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles"
```

## 日常维护

```bash
brew update              # 更新 brew 自身
brew upgrade             # 升级所有包
brew upgrade <pkg>       # 升级指定包
brew cleanup             # 清理旧版本
brew list                # 列出已安装包
brew leaves              # 列出顶层依赖
brew bundle dump         # 导出当前包到 Brewfile
brew bundle check        # 检查 Brewfile 中的包是否都已安装
```
