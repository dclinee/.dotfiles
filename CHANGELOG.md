# 变更日志 (Changelog)

本项目的所有重要变更将记录在此文件。格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### 待发布 (下一个 Minor/Patch 版本)

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
- **集成测试**：Dockerfile.test + test_integration.sh (14 维度 73 项检查)，CI 中新增 integration-test job
- **ShellCheck CI lint**：warning 级 lint，.shellcheckrc 配置
- **架构文档**：`docs/ARCHITECTURE.md`（架构图 + 加载流程 + 依赖关系）
- **架构决策记录**：`docs/ADR.md`（10 条 ADR）
- **版本发布说明**：`docs/RELEASE_NOTES_v2.0.0.md`（完整改进说明）
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
- test_install.sh: 104/104 通过 (100%)
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
- validate.sh + test_install.sh 基础测试框架
