# 分层安装策略

## 四层安装顺序

模块按依赖关系分为四层，从基础到开发逐层安装：

```
基础层                编辑器层              终端层              开发层
┌──────────┐      ┌──────────┐      ┌──────────┐      ┌──────────┐
│EditorConfig│     │   Vim    │      │ WezTerm  │      │  Python  │
│   Git     │ ──▶ │  Emacs   │ ──▶ │  Tmux    │ ──▶ │  Rust    │
│   Brew    │      │          │      │          │      │          │
└──────────┘      └──────────┘      └──────────┘      └──────────┘
     │
     ▼  依赖关系
  Brew 为后续所有模块提供包管理基础
  Git 为后续所有模块提供版本控制基础
  EditorConfig 为所有编辑器提供统一缩进规则
```

## 完整安装顺序

`bootstrap.sh` 按以下顺序调用各模块：

1. **基础层**（无依赖，提供基础设施）
   - EditorConfig — 跨编辑器缩进/换行/编码规则
   - Git — 别名/颜色/pager 模板
   - Brew — 包管理基础（所有后续模块依赖）

2. **编辑器层**（依赖 Brew 提供的包）
   - Zsh — 主 shell + zinit + starship
   - Vim — vim-plug + 常用插件
   - Emacs — init.el + lisp 模块化配置

3. **终端层**（依赖 Brew）
   - WezTerm — Lua 模块化终端配置
   - Tmux — TPM 插件 + Vim 风格快捷键

4. **开发层**（依赖 Brew 和编辑器配置）
   - Python — uv + pip 镜像
   - Rust — rustup + cargo 镜像

## 选择性安装

`bootstrap.sh` 支持按模块单独安装：

```bash
./bootstrap.sh --zsh      # 仅安装 Zsh
./bootstrap.sh --vim      # 仅安装 Vim
./bootstrap.sh --tmux     # 仅安装 Tmux
./bootstrap.sh --git      # 仅安装 Git 配置
./bootstrap.sh --brew     # 仅安装 Brew 包
./bootstrap.sh --pwsh     # 仅安装 PowerShell 配置
./bootstrap.sh --all      # 安装全部（默认）
```

:::warning 注意
基础层（尤其 Brew）失败会影响后续所有模块。建议新机器先执行 `./bootstrap.sh --brew` 确认基础环境就绪，再执行 `--all`。
:::

## 相关 ADR

- [ADR-001: bootstrap.sh 主安装入口](/decisions/adr-001)
- [ADR-002: 分层安装顺序](/decisions/adr-002)

## Docker 模块（独立于四层安装）

[Docker 模块](/modules/docker) 是容器化开发环境与 CI 集成测试用的，**不参与** bootstrap.sh 的四层安装顺序。它独立提供：

- 开发容器（`./docker/build.sh shell dev`）：预装完整 dotfiles 配置的交互式环境
- CI 测试镜像（`docker/Dockerfile.ci`）：GitHub Actions integration-test job 用
- 多发行版验证矩阵：Ubuntu / Debian / Fedora 三平台端到端测试
