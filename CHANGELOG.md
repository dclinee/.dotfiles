# 变更日志 (Changelog)

本项目的所有重要变更将记录在此文件。格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

## [Unreleased]

计划版本号：**v2.1.0**（新增模块与功能，无破坏性变更）

### ✨ Added / 新增
- **`docker/` 容器化模块**：多阶段 Dockerfile（Ubuntu/Debian/Fedora 测试矩阵 + 开发镜像）、docker-compose.yml（dev/validate/test 多服务）、build.sh 统一操作脚本、.env.example、.dockerignore；支持国内镜像加速（USTC apt + NO_MIRROR 开关）。Makefile 新增 `docker-build/up/test/validate/clean` 五个 target
- **`editorconfig/` 独立模块**：install.sh + _common.sh，bootstrap.sh 最后一个内嵌安装函数完成抽离
- **`pwsh/` 跨平台 PowerShell 模块**：兼容 PowerShell 7+ 与 Windows PowerShell 5.1，覆盖 Profile/别名/函数/提示符/PSReadLine；Windows 符号链接三层降级（SymbolicLink → Junction/HardLink → Copy）；Git 配置联动（credential.helper 自动适配 Git for Windows）；bootstrap.sh `--pwsh`、Makefile `pwsh`/`pwsh-check`、`make doctor` 第 10 个模块
- **PowerShell 体检与验证**：`pwsh/check.ps1`（PS 原生体检：版本/文件完整性/Profile 链接/PSReadLine/加载冒烟测试）+ `pwsh/check.sh`（bash 封装，无 pwsh 时跳过）；`validate.sh` 新增 PS AST 语法解析段；CI 新增 PowerShell syntax-check step；`tests/test_install.sh` 新增 30 项断言（BOM 校验、文件存在、集成检查）
- **`lib/_module_loader.sh` 模块公共加载器**：统一 11 个模块 _common.sh 的路径解析样板，消除重复代码
- **`make doctor` 全模块环境体检**：顺序聚合 10 个模块 check.sh，单模块失败不中断并汇总；补齐 brew/git/tmux/vim/zsh 五个缺失的 `*-check` target
- **`bootstrap.sh --dry-run`**：预演模式，只打印将执行的软链操作不落地（复用 lib/common.sh 的 is_dry_run 机制）
- **`validate.sh` 覆盖扩充**：新增 Git（git config 解析）、Tmux（start-server 语法）、Python、Rust、Vim（headless source）五项验证
- 新增 brew/git/tmux/vim/zsh 五个模块的 `check.sh` 运行时体检脚本
- 新增 git/wezterm/docker 三个模块的 `.gitignore`；根 `.gitignore` 补充 `*.elc`、测试覆盖率产物、nvim.log 等
- 新增 `SECURITY.md` 安全策略文档
- **VitePress 文档站补全**：新增决策记录（ADR-001~010 拆分页）、贡献指南、测试文档、变更日志等 14 个页面；新增 `docs/archive/` 归档目录
- Emacs 新增 DeepSeek AI、consult-projectile 集成（见 Changed）
- **Makefile install 输出美化**：新增 `lib/make-output.sh`，`make install` 显示 box-drawing 横幅、步骤计数 `[1/12]`、每模块耗时、汇总报告表；各子目标通过 `timed_bootstrap` 宏自动计时
- **PowerShell 双行彩色 prompt 主题**：不依赖 Nerd Font（Cascadia/Consolas 可渲染）；第一行显示失败退出码/venv/智能缩短路径/Git 聚合状态（分支·ahead-behind·暂存/改动/未跟踪/冲突计数）/后台任务/命令耗时，第二行 `❯`（成功绿/失败红/管理员 ⚡）；新增 `Get-GitPromptInfo` 单次 porcelain 聚合；PSReadLine 语法配色与续行提示符；重定向时自动降级纯文本；`check.ps1` 冒烟测试增强为实际调用 `prompt`

### 🔄 Changed / 变更
- **Emacs 补全体系从 Helm 迁移到 Vertico/Consult**：M-x、C-x b、C-x C-f、M-y 等统一走 Vertico + Orderless + Marginalia；C-s 恢复为标准 isearch（anzu 重新生效）；项目查找改用 consult-projectile
- **`bootstrap.sh` 全面模块化**：brew/python/rust/ssh/editorconfig 内嵌安装逻辑全部改为委托各模块 install.sh，文件从 1024 行降至约 850 行，所有 install_* 函数统一为一行委托
- **`Dockerfile.test` 迁移为 `docker/Dockerfile.ci`**：CI workflow 引用同步更新
- **测试脚本迁移到 `tests/` 目录**：`test_install.sh`/`test_integration.sh` 统一收纳，全仓库 40+ 处引用同步更新（CI、Docker、文档、PR 模板）
- **CI 接入模块体检**：static-tests job 新增各模块 check.sh 检查步骤（容错运行，环境缺工具不误红）
- 各模块 `_common.sh` 统一改为 source `lib/_module_loader.sh`，不再各自实现路径解析
- Emacs custom.el 的 package-selected-packages 移除 helm-org/helm-projectile/helm-rg 声明
- 全面重写 emacs/README.md，修正与实际 lisp/ 结构（82 个功能命名模块）不符的过时描述
- 全量同步项目文档以对齐 docker/editorconfig 新模块、tests/ 新路径、Vertico 新补全体系

### 🐛 Fixed / 修复
- **PowerShell Profile 在 Windows 跨盘 HardLink/Copy 兜底时加载失败**：Documents 重定向到非系统盘（如 D 盘）且仓库在 C 盘时，符号链接无权限、硬链接不可跨卷，安装器仅复制单个 profile.ps1，导致同目录的 `_common.ps1` 与 `modules/` 全部找不到。`New-SafeLink` 新增 `-CompanionPaths` 伴生同步（目录 Junction 跨卷、文件 HardLink→Copy，幂等）；`profile.ps1` 路径解析改为四级回退链（自身→符号链接 Target→`$env:DOTFILES_ROOT\pwsh`→`$HOME\.dotfiles\pwsh`），旧版孤立副本亦可自愈；新增 6 项静态断言
- **全部 `.ps1` 文件的双重 UTF-8 BOM**：双 BOM 使 `#requires` 指令失效并导致 `[CmdletBinding()]param()` AST 解析错误；统一修正为单 BOM，静态测试新增"禁止重复 BOM"断言（每个 ps1 检查）
- **marginalia 与 Emacs 30.2 兼容崩溃**：marginalia 快照调用 3 参数版 `seconds-to-string`（Emacs 31 签名），在 30.2 上触发 wrong-number-of-arguments，导致 Vertico 候选注解报错；新增基于 compat-31 的行为探针 advice 桥接
- **vterm 无法加载 `libvterm.so.0`**：Homebrew 版 Emacs 的动态链接器默认不搜索系统库目录；通过 `brew install libvterm`（0.3.3 与模块版本一致）经 DT_RPATH 传递解析修复
- **init-ibuffer 直绑 C-x b 到 ido-switch-buffer**：Helm 移除后暴露的隐藏冲突，改为 consult-buffer
- **修复 _common.sh 重构回归**：精简样板时误删 ssh 的 get_ssh_version/get_file_mode、vim 的 get_vim_version/have_sudo、emacs/wezterm/zsh 的 get_*_version，导致相关 install.sh/check.sh 中断（exit 127），已全部恢复
- 修复 VitePress @include 场景下 vim/README.md、CONTRIBUTING.md 的两个相对路径死链（改为 GitHub 绝对 URL）
- **修复 brew bundle 模块化回归**：bootstrap 模块化委托后，两层 `brew bundle`（通用 + 平台 Brewfile）调用丢失，已移入 `brew/install.sh` 的 `_bundle_brewfiles`，并支持 `--dry-run` 只打印不执行
- 修复 `tests/test_install.sh` 迁移到 `tests/` 后 `DOTFILES_DIR` 未上溯一级导致静态测试路径全部失效的问题；同步更新 brew bundle 断言位置

### 🗑 Removed / 移除
- Helm 补全体系停用（`init-helm.el` 保留但标记弃用且不再 require，便于回退；确认稳定后将卸载 helm/helm-core/helm-org/helm-projectile/helm-rg）

---

## [2.0.0] - 2026-08-10

### ⚠️ BREAKING CHANGES / 破坏性变更
- **brew/install_brew.sh → brew/install.sh 重命名**：统一模块脚本命名，外部调用 `brew/install_brew.sh` 的脚本需要更新路径。
- **git hooksPath 硬编码改为 `~/.dotfiles/git/hooks`**：之前使用硬编码绝对路径 `/home/dclee/...`，新配置在任何用户下均可工作。
- **alias `br` 不再是 `brew reinstall`**：现改为 `brr='brew reinstall'`，原 `br='brew'` 保留。

### ✨ Added / 新增
- `bootstrap.sh` **自动回滚机制**：模块安装失败自动恢复修改前状态，支持 `--rollback [dir]` 全量回滚
- `zsh/platform/wsl.zsh` **WSL 平台专属配置**：Windows 互操作、剪贴板同步、WSLg GUI、SSH Agent 转发、文件系统优化
- **代码覆盖率报告 (kcov CI job)**：ShellCheck 之外新增 kcov 覆盖率报告 job，artifact 上传
- **CI 依赖缓存**：actions/cache 缓存 apt 包、kcov 构建、Docker buildx 层、集成测试层
- **集成测试**：Dockerfile.test + tests/test_integration.sh (14 维度 73 项检查)，CI 中新增 integration-test job
- **ShellCheck CI lint**：warning 级 lint，.shellcheckrc 配置
- **架构文档**：[架构总览](https://github.com/dclinee/.dotfiles/blob/main/docs/archive/ARCHITECTURE.md)（架构图 + 加载流程 + 依赖关系，已拆分为 VitePress 子页面）
- **架构决策记录**：[ADR 索引](https://github.com/dclinee/.dotfiles/blob/main/docs/archive/ADR.md)（10 条 ADR，已拆分为独立页面）
- **版本发布说明**：[RELEASE_NOTES_v2.0.0](https://github.com/dclinee/.dotfiles/blob/main/docs/archive/RELEASE_NOTES_v2.0.0.md)（完整改进说明）
- **模块 README**：`zsh/`, `vim/`, `wezterm/`, `python/`, `rust/`, `emacs/` 六模块独立文档
- **asdf 版本管理**：`.tool-versions` 固定 Python/Rust/Node/Go/Tmux/Zsh 版本
- **GitHub PR 模板**：`.github/PULL_REQUEST_TEMPLATE.md`
- **Conventional Commits 提示**：commit-msg hook 增加格式建议
- `.venv` **自动切换**：进入目录自动激活，离开自动停用

### 🐛 Fixed / 修复
- **6 个 Major 问题**：
  - 删除 zsh/install.sh 中 200+ 行死代码
  - `readlink -f` macOS < 13.0 兼容性（`_resolve_link` 函数）
  - `.venv` 离开目录未 deactivate（chpwd_functions 双向切换）
  - `git-commit` 函数 `git add .` 安全风险（分拆 git-commit-tracked）
  - `alias python=python3` 绕过虚拟环境（仅非 venv 设置）
  - CI 仅 Ubuntu 单平台（新增 macOS 双平台矩阵）
- **10 个 Minor 问题**：
  - Makefile install 顺序与 bootstrap 对齐
  - bootstrap 输出风格统一 (emoji → Oh My Zsh)
  - `VIRTUALENVWRAPPER_PYTHON` 命令存在性检查
  - `compress` 兼容性 (zsh `${@:3}` → POSIX shift)
  - pre-commit 重复 grep（性能 + pipefail）
  - wezterm.lua is_array 严格判断（避免稀疏表误判）
  - lib/common.sh xargs 修剪空白改为参数扩展
  - _current_login_shell pipefail 修复
  - Makefile update target git pull 失败不忽略
  - 未使用变量/命令存在性修复

### ♻️ Changed / 变更
- Python/Rust/WezTerm `_common.sh` 明确标注"调用者已设置 set -euo pipefail"注释
- `validate.sh` `set -eo pipefail` → `set -euo pipefail`
- `zsh/profile_performance.sh` 新增 `set -euo pipefail`

### 🧪 Tests / 测试
- 新增集成测试: 96/96 通过
- tests/test_install.sh: 104/104 通过 (100%)
- 语法检查: bash -n / zsh -n / make -n 全通过

---

## [1.4.0] - 2026-08-09

### ✨ Added / 新增
- 安装顺序分层重构（基础层 → 编辑器层 → 终端层 → 开发层）
- Git Hooks：pre-commit 尾随空格 + CRLF 检查
- commit-msg hook 首行长度限制
- pre-push main/master 分支保护
- GitHub CLI 14 个别名 (ghpr/ghissue/ghworkflow 等)
- `.github/workflows/ci.yml` CI 配置（语法检查 + 静态测试 + 定时 cron）
- `.gitattributes` 自动行尾管理
- Git `credential.helper=cache` 内存缓存 (替换明文 store)
- EditorConfig 模块独立化

### 🐛 Fixed / 修复
- zsh/core/00_env.zsh pyenv 懒加载函数
- `hooksPath` 从硬编码改为 `~/.dotfiles/git/hooks`
- Token workflow scope 推送 CI 配置修复文档

---

## [1.3.0] - 2026-08-09

### ✨ Added / 新增
- Homebrew USTC 镜像安装脚本
- Brewfile 通用 / Linux / macOS 分层
- 国内镜像加速 (USTC/Tsinghua/ghproxy 82 处)
- 临时文件下载 + SHA256 校验 (starship/zinit 脚本)
- 超时控制 (--connect-timeout 15 --max-time 60)

### 🐛 Fixed / 修复
- zinit 手动 git clone → 改用 zinit
- `eval $(brew shellenv)` 子脚本 PATH 丢失 (改为 source)
- `date -r` macOS/Linux 跨平台差异（改用 stat）
- 空插件目录漏检 (ls -A 内容检查)

---

## [1.2.0] - 2026-06-15

### ✨ Added / 新增
- zinit 插件管理器集成
- Starship 提示符（Nerd Font 检测 + 回退）
- eza 替代 ls，zoxide 替代 cd
- ftplugin 语言缩进规范（Python 4/JS 2/Go tabs/Makefile tabs/Rust 4）
- Vim 9+ `\` 连续行语法兼容修复
- `silent! colorscheme` 主题缺失不阻塞

---

## [1.1.0] - 2026-04-01

### ✨ Added / 新增
- lib/output.sh 公共输出函数
- lib/common.sh 命令探测/包安装
- lib/symlink.sh 自动备份/冲突处理
- COMPLETED/FAILED 步骤追踪 + 汇总报告
- Python requirements 分层 (base/dev/data/web)
- pip 国内镜像配置

---

## [1.0.0] - 2026-01-01

### ✨ Added / 新增
- 项目首次发布
- 11 模块基础结构 (brew/emacs/git/lib/python/rust/tmux/vim/wezterm/zsh)
- bootstrap.sh 一键安装入口
- Makefile: install/clean/check/update/uninstall
- validate.sh + tests/test_install.sh 基础测试框架
