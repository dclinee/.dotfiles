# Zsh 模块

高度优化的 Zsh 配置框架，聚焦启动性能、跨平台兼容和智能功能。

## 目录结构

```
zsh/
├── .zshenv              # 环境变量入口（所有 shell 加载）
├── .zshrc               # 主配置入口（交互式 shell 加载）
├── install.sh           # Zsh 安装脚本
├── profile_performance.sh  # 启动性能分析脚本
├── core/                # 核心配置（按编号顺序加载）
│   ├── 00_env.zsh       # 环境变量
│   ├── 01_options.zsh   # Zsh 选项
│   ├── 02_aliases.zsh   # 别名定义
│   ├── 03_functions.zsh # 自定义函数
│   ├── 04_plugins.zsh   # 插件加载（zinit）
│   └── 05_starship.zsh # 提示符（Starship）
├── platform/            # 平台特定配置
│   ├── linux.zsh        # Linux 专属
│   ├── macos.zsh        # macOS 专属
│   └── wsl.zsh          # WSL (Windows) 专属
├── starship/            # Starship 提示符主题
│   ├── starship.toml    # Nerd Font 版本
│   └── starship_fallback.toml  # 纯文本回退版本
└── plugins/             # 插件配置
    └── zoxide/init.zsh  # zoxide 智能跳转
```

## 配置加载流程

```
.zshenv
  └─▶ PATH / DOTFILES_ROOT / 语言环境 / asdf 检测

.zshrc
  └─▶ 00_env.zsh     (pyenv/rbenv/nvm、.venv 自动切换)
      01_options.zsh (历史记录、补全、目录栈)
      02_aliases.zsh (ls/eza/vim/python 别名)
      03_functions.zsh (mkcd/extract/compress/git-commit)
      04_plugins.zsh (zinit 懒加载)
      05_starship.zsh (字体检测 + 提示符)
      platform/{linux,macos,wsl}.zsh (平台配置)
```

## 核心特性

### ⚡ 启动性能

| 机制 | 效果 |
|------|------|
| zinit 懒加载 (`wait lucid`) | 非关键插件延迟加载，节省 ~100ms |
| compinit 缓存 (mtime + `-C -s`) | 增量检查，避免每次重建补全 |
| zoxide 延迟初始化 | 首次 `z` 命令才 eval，节省 ~30ms |
| pyenv 懒加载函数 | 首次 `pyenv` 命令才 eval |
| .venv `chpwd_functions` 切换 | 进入目录自动激活，离开自动停用 |

### 🛡️ 别名安全

- `python/pip` 别名仅非虚拟环境设置（不绕过 venv）
- `git-commit` 不自动 `git add .`（不提交敏感文件）
- 冲突别名定义前先 `unalias xx 2>/dev/null || true`

### 🎨 智能提示

- 目录不存在时自动建议正确路径
- 命令不存在时自动建议拼写修正
- Starship 提示符：显示 Git 状态、Python venv、Rust toolchain

### 🌐 跨平台

- `OSTYPE` + `uname` 双重检测
- Linux/macOS/WSL 配置完全分离
- Homebrew 路径自适应（Linuxbrew / /opt/homebrew / /usr/local）

## 常用功能速查

| 功能 | 命令 |
|------|------|
| 快速跳转 | `z <partial-name>` (zoxide) |
| 创建并进入目录 | `mkcd <path>` |
| 解压多种格式 | `extract <archive>` |
| 压缩目录 | `compress <name> tar.gz <files>` |
| 快速提交已跟踪文件 | `git-commit-tracked "message"` |
| 查看磁盘使用 | `dud` (top 10 大文件) |
| 快速编辑配置 | `ez` / `ev` / `etm` / `ew` |
| 智能 ls | `ll` / `la` / `lt` (tree-like, 基于 eza) |

## 安装

```bash
cd ~/.dotfiles
./zsh/install.sh

# 或通过 Makefile
make zsh
```

安装后将 Zsh 设为默认 shell：

```bash
chsh -s "$(command -v zsh)"
```

## 性能分析

```bash
cd ~/.dotfiles
./zsh/profile_performance.sh
```

输出冷启动/热启动时间对比，以及 20 个最耗时配置项明细。
