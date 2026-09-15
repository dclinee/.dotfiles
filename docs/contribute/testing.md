# 测试与验证

本项目构建了多层次的测试金字塔：从静态语法检查 → 单元测试 → 集成测试，确保每次提交都不会破坏完整安装流程。

## 测试矩阵概览

| 层级 | 工具 | 触发位置 | 覆盖内容 |
|------|------|----------|----------|
| 语法检查 | `bash -n` / `zsh -n` / `make -n` | 本地 + CI | 所有 shell 脚本语法 |
| 静态分析 | ShellCheck | 本地 + CI | 潜在 bug 与最佳实践 |
| 配置验证 | `validate.sh` | 本地 + CI | SSH/Emacs/Git 等配置语法 |
| 安装体检 | 各模块 `check.sh`（`make doctor` 聚合） | 本地 + CI | 9 模块工具/软链/配置就位情况（只读） |
| 静态测试 | `tests/test_install.sh static` | 本地 + CI | 104 个断言（符号链接、文件存在性） |
| 集成测试 | `tests/test_integration.sh` (Docker) | 本地（可选）+ CI | 73 项检查（14 维度端到端安装） |
| 覆盖率 | kcov | CI | 覆盖率报告 artifact 上传 |

## 本地测试

### 1. 静态语法检查（最快）

```bash
bash tests/test_install.sh static
```

执行 `bash -n` / `zsh -n` / `make -n` 检查所有脚本语法。CI 跑同一套，是提交前的最低门槛。

### 2. 配置语法验证

```bash
bash validate.sh
```

验证 SSH 配置（`ssh -F ssh/config -G github.com`）、Emacs 字节编译（`emacs --batch -f batch-compile`）等。命令缺失时自动跳过对应检查。

### 2.5 模块安装体检

```bash
make doctor          # 聚合 9 个模块的 check.sh，容错执行并汇总通过/失败数
bash git/check.sh    # 或单独体检某个模块
```

`check.sh` 是只读检查（工具版本、软链指向、配置就位），不做任何安装动作；存在失败项时退出码为 1，警告不影响退出码。

### 3. 完整静态测试

```bash
bash tests/test_install.sh all
```

包含动态模拟安装，覆盖 104 个断言（CI 不跑动态部分以节省时间）。

### 4. 集成测试（Docker）

```bash
# 方式 1：用 docker/ 模块的 build.sh（推荐）
./docker/build.sh test

# 方式 2：手动构建 CI 镜像
docker build -f docker/Dockerfile.ci -t dotfiles-test .
docker run --rm dotfiles-test
```

基于 Ubuntu 24.04 的完整安装环境，执行 `bootstrap.sh --all` 后运行 73 项端到端检查（覆盖 14 个维度）。Docker 模块还支持多发行版矩阵测试（Ubuntu/Debian/Fedora），见 [Docker 模块](/modules/docker)。

## CI 测试流水线

GitHub Actions 在 `push` / `pull_request` / 每周一 00:00 UTC 触发：

| Job | Runner | 用途 |
|-----|--------|------|
| `shellcheck` | ubuntu-latest | ShellCheck lint（warning 级别） |
| `syntax-check` | ubuntu + macOS | 双平台语法检查 |
| `static-test` | ubuntu-latest | `validate.sh` + 模块 `check.sh` 体检 + `tests/test_install.sh static` |
| `integration-test` | ubuntu-latest | Docker 容器端到端安装 |
| `coverage` | ubuntu-latest | kcov 覆盖率报告 |

:::tip 本地复现 CI
所有 CI 命令都可在本地直接运行，无需特殊环境。Docker 集成测试需要本地安装 Docker。
:::

## 测试覆盖维度

集成测试 73 项检查覆盖 14 个维度：

| 维度 | 检查项数 | 示例 |
|------|----------|------|
| 符号链接 | 9 | `.zshrc`, `.vimrc`, `.gitconfig`, `.tmux.conf` |
| Zsh 配置 | 8 | 语法检查、交互启动、core/platform 目录 |
| Vim 配置 | 6 | 语法检查、ftplugin、platform 目录 |
| Git 配置 | 7 | hooksPath、credential.helper、hooks 可执行 |
| Brew 配置 | 5 | brew 命令、Brewfile、install.sh |
| Python 配置 | 5 | python3、pip.conf、requirements |
| Rust 配置 | 4 | cargo、rustfmt.toml、clippy.toml |
| WezTerm 配置 | 6 | core/platform 目录、lua 文件 |
| Tmux 配置 | 2 | `.tmux.conf`、tmux 命令 |
| Emacs 配置 | 3 | init.el 链接、语法编译 |
| 公共库 | 6 | lib/*.sh、bootstrap.sh、validate.sh |
| CI/CD | 6 | ci.yml、Makefile、.editorconfig |
| Makefile | 3 | help、install、update 可执行 |
| 环境变量 | 3 | DOTFILES_ROOT、PATH、EDITOR |

## 编写新测试

新增功能时建议同时添加测试：

1. **静态断言**：添加到 `tests/test_install.sh` 的 `test_static_*` 函数，检查文件存在性 / 符号链接正确性。
2. **集成检查**：添加到 `tests/test_integration.sh`，确保 `bootstrap.sh --all` 安装后功能可用。
3. **配置验证**：涉及 SSH/Emacs/Git 配置时，扩展 `validate.sh` 的功能检查。

详见 [贡献指南](/contribute/) 的 Review Checklist。
