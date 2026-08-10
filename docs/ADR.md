# 架构决策记录 (ADR)

## 目录

- [ADR-001: 使用 bootstrap.sh 作为主安装入口](#adr-001-使用-bootstrapsh-作为主安装入口)
- [ADR-002: 分层安装顺序（基础→编辑器→终端→开发）](#adr-002-分层安装顺序基础编辑器终端开发)
- [ADR-003: 使用 zinit 而非手动 git clone 管理插件](#adr-003-使用-zinit-而非手动-git-clone-管理插件)
- [ADR-004: 配置文件模块化为 core/platform/ftplugin 分层](#adr-004-配置文件模块化为-coreplatformftplugin-分层)
- [ADR-005: 使用 safe_symlink 统一符号链接管理](#adr-005-使用-safe_symlink-统一符号链接管理)
- [ADR-006: Git 凭证使用 cache 而非 store](#adr-006-git-凭证使用-cache-而非-store)
- [ADR-007: 国内镜像源 + 代理回退策略](#adr-007-国内镜像源--代理回退策略)
- [ADR-008: COMPLETED/FAILED 步骤追踪机制](#adr-008-completedfailed-步骤追踪机制)
- [ADR-009: Vim 9+ 兼容性：禁用 \ 行连续](#adr-009-vim-9-兼容性禁用--行连续)
- [ADR-010: Brew bundle 分层文件策略](#adr-010-brew-bundle-分层文件策略)

---

## ADR-001: 使用 bootstrap.sh 作为主安装入口

**状态**: 已接受
**日期**: 2025-01-01

### 背景

dotfiles 项目包含 11 个模块（Zsh、Vim、Emacs、WezTerm、Brew、Git、Python、Rust、Tmux、EditorConfig），每个模块有独立的 install.sh。需要一个统一入口管理安装顺序和依赖。

### 决策

使用 `bootstrap.sh` 作为主安装入口，通过 `--all` 或 `--<module>` 参数控制安装范围，内部按依赖顺序调用各模块的 install.sh。

### 后果

- 优点：单一入口、依赖可控、支持选择性安装
- 缺点：bootstrap.sh 需要了解所有模块的依赖关系

---

## ADR-002: 分层安装顺序（基础→编辑器→终端→开发）

**状态**: 已接受
**日期**: 2025-06-01

### 背景

原安装顺序（Zsh → Vim → ... → Brew）导致依赖混乱：Zsh 内部尝试安装 Brew，而 Brew 应在 Zsh 之前。

### 决策

将安装顺序分为四层：
1. **基础层**: EditorConfig → Git → Brew（所有后续模块的基础）
2. **编辑器层**: Zsh → Vim → Emacs（依赖 Brew 提供的包）
3. **终端层**: WezTerm → Tmux（依赖 Brew）
4. **开发层**: Python → Rust（依赖 Brew 和编辑器配置）

### 后果

- 优点：依赖关系清晰、无循环依赖、Brew 只安装一次
- 缺点：基础层失败会影响后续所有模块

---

## ADR-003: 使用 zinit 而非手动 git clone 管理插件

**状态**: 已接受
**日期**: 2025-01-15

### 背景

Zsh 插件管理有多种方案：oh-my-zsh、antigen、zinit、手动 git clone。手动 clone 难以更新和卸载。

### 决策

使用 zinit 管理插件，配合 `wait lucid` 实现懒加载。

### 后果

- 优点：插件管理自动化、懒加载提升启动速度、支持 turbo mode
- 缺点：依赖 zinit 框架本身（需 brew 安装）

---

## ADR-004: 配置文件模块化为 core/platform/ftplugin 分层

**状态**: 已接受
**日期**: 2025-02-01

### 背景

单个大配置文件（如 500 行 .zshrc）难以维护，平台差异混在一起。

### 决策

将配置文件按功能分层：
- `core/` — 核心配置（环境、选项、别名、函数、插件）
- `platform/` — 平台特定配置（linux/macos/windows）
- `ftplugin/` — 文件类型配置（Vim 专属）
- 按编号排序加载（00_、01_、02_...）

### 后果

- 优点：职责分离、易于维护、平台差异隔离
- 缺点：文件数量增多

---

## ADR-005: 使用 safe_symlink 统一符号链接管理

**状态**: 已接受
**日期**: 2025-01-20

### 背景

直接使用 `ln -sf` 创建符号链接存在风险：覆盖已有文件、不检查源文件、跨平台兼容性问题。

### 决策

实现 `safe_symlink()` 函数：
1. 检查源文件存在
2. 已是正确链接则跳过
3. 已存在文件则备份为 `.bak`
4. 使用 `_resolve_link()` 跨平台解析路径

### 后果

- 优点：安全、幂等、跨平台
- 缺点：函数实现较复杂

---

## ADR-006: Git 凭证使用 cache 而非 store

**状态**: 已接受
**日期**: 2025-07-01

### 背景

`credential.helper=store` 会将 Token 明文保存在 `~/.git-credentials`，存在安全风险。

### 决策

使用 `credential.helper=cache` 内存缓存 1 小时，旧明文文件备份为 `.bak`。

### 后果

- 优点：凭证不落盘、自动过期
- 缺点：每次重启需重新输入凭证

---

## ADR-007: 国内镜像源 + 代理回退策略

**状态**: 已接受
**日期**: 2025-03-01

### 背景

国内访问 GitHub、Homebrew 等资源缓慢，直接影响安装体验。

### 决策

- Homebrew: 使用 USTC 镜像
- Emacs 包: 使用清华镜像（gnu/nongnu/melpa）
- GitHub 资源: 使用 ghfast.top/ghproxy.com 代理回退
- 设置超时控制（--connect-timeout 15 --max-time 60）

### 后果

- 优点：国内安装速度快、有回退保障
- 缺点：镜像源可能不同步最新版本

---

## ADR-008: COMPLETED/FAILED 步骤追踪机制

**状态**: 已接受
**日期**: 2025-04-01

### 背景

安装脚本在 `set -euo pipefail` 下任一步骤失败会中断，用户无法知道哪些模块成功、哪些失败。

### 决策

使用 `COMPLETED_STEPS` 和 `FAILED_STEPS` 数组追踪每个模块的安装状态，最终输出汇总报告。单个模块失败不中断后续模块。

### 后果

- 优点：安装结果清晰、部分失败不影响整体
- 缺点：需要为每个模块添加 try/catch 逻辑

---

## ADR-009: Vim 9+ 兼容性：禁用 \ 行连续

**状态**: 已接受
**日期**: 2025-05-01

### 背景

Vim 9.2+ 不再支持 `\` 行连续语法，第三方插件（coc.nvim、vim-fugitive）可能出现兼容性问题。

### 决策

所有 Vim 脚本使用单行或替代连续方法，不使用 `\` 行连续。colorscheme 使用 `silent!` 避免阻塞。

### 后果

- 优点：Vim 9+ 兼容
- 缺点：部分代码行较长

---

## ADR-010: Brew bundle 分层文件策略

**状态**: 已接受
**日期**: 2025-06-15

### 背景

`brew bundle` 不支持嵌套引用其他 Brewfile（`brewfile 'Brewfile.common'` 会报错）。

### 决策

- `Brewfile` — 通用包（所有平台共享）
- `Brewfile.linux` — Linux 特有包
- `Brewfile.macos` — macOS 特有包
- 安装时按平台依次执行 `brew bundle`

### 后果

- 优点：跨平台支持、无嵌套问题
- 缺点：包列表分散在三个文件中
