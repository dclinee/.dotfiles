# 模块总览

Dotfiles 共有 12 个独立模块，每个模块自带 `_common.sh` 公共加载器，可单独安装或通过 `bootstrap.sh` 统一部署。

## 模块清单

| 模块 | 路径 | 主要工具/配置 | 依赖 | 说明 |
|------|------|--------------|------|------|
| **Zsh** | `zsh/` | zinit, starship, eza, zoxide | Brew | 主 shell 配置入口 |
| **Vim** | `vim/` | vim-plug + 常用插件 | Brew (vim) | Vim 编辑器配置 |
| **Emacs** | `emacs/` | init.el + lisp/init-*.el | Brew (emacs) | Emacs 配置（ellama/consult 等） |
| **WezTerm** | `wezterm/` | wezterm.lua + core/ | Brew (wezterm) | 跨平台终端配置 |
| **Tmux** | `tmux/` | TPM + Vim 风格快捷键 | Brew (tmux) | 终端复用器 |
| **Python** | `python/` | uv, pip 镜像 | Brew (python, uv) | Python 工具链 |
| **Rust** | `rust/` | rustup, cargo 镜像 | Brew (rustup) | Rust 工具链 |
| **Homebrew** | `brew/` | Brewfile 分层 | 无 | 包管理基础 |
| **Git** | `git/` | 别名/颜色/pager | 无 | 版本控制配置 |
| **SSH** | `ssh/` | config.d 分片 | 无 | SSH 多机配置 |
| **EditorConfig** | `editorconfig/` | `.editorconfig` 软链 | 无 | 跨编辑器统一缩进/换行/编码（极简模块） |
| **Docker** | `docker/` | 多发行版镜像 + compose | 无 | 容器化开发环境 + CI 集成测试 |

## 模块脚本标准结构

完整模块遵循 `_common.sh` 模式，核心文件 3 件套：

```
<module>/
├── install.sh        # 主安装入口（必须）
├── check.sh          # 安装状态检查（推荐）
├── _common.sh        # 共享函数（委托 lib/_module_loader.sh + lib/common.sh，必须）
├── README.md         # 模块文档（必须）
├── .gitignore        # 模块私有忽略（推荐）
├── uninstall.sh      # 卸载（可选，大模块如 python/rust 才有）
├── clean.sh          # 清理缓存（可选）
├── upgrade.sh        # 升级依赖（可选）
├── pin.sh            # 版本锁定（可选）
└── tools.list        # 工具清单（可选，python/rust 用）
```

> Docker/editorconfig 模块是例外：Docker 是容器编排模块（无 install.sh），editorconfig 极简（只有一个软链）。

## 模块分类

### 配置模块
- [Zsh](/modules/zsh) — 主 shell，命令行体验核心
- [Vim](/modules/vim) — Vim 编辑器
- [Emacs](/modules/emacs) — Emacs 编辑器
- [WezTerm](/modules/wezterm) — 跨平台终端
- [Tmux](/modules/tmux) — 终端复用器

### 工具链模块
- [Python](/modules/python) — Python 工具链
- [Rust](/modules/rust) — Rust 工具链
- [Homebrew](/modules/brew) — 包管理基础

### 其他模块
- [SSH](/modules/ssh) — SSH 配置
- [Git](/modules/git) — Git 全局配置
- EditorConfig — 跨编辑器代码风格统一（极简，仅一个软链，无独立文档页）
- [Docker](/modules/docker) — 容器化开发环境与 CI 集成测试

## 安装顺序

模块按四层依赖顺序安装，详见 [分层安装策略](/architecture/install-order)。

```
基础层 → 编辑器层 → 终端层 → 开发层
```
