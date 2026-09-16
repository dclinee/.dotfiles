# 安装方式

推荐通过仓库根目录的 `bootstrap.sh` 统一安装，也可单独执行各模块的 `install.sh`。所有脚本支持 `--help` 查看参数。

## 统一入口 bootstrap.sh

```bash
./bootstrap.sh              # 安装全部模块（默认 --all）
./bootstrap.sh --git --ssh  # 仅安装指定模块（可任意组合）
./bootstrap.sh --all --dry-run  # 预演模式（见下）
```

### 预演模式（--dry-run）

安装前不确定会改动哪些文件时使用：

- 导出 `DRY_RUN=true` 给所有子模块安装器
- `safe_symlink`、备份（`mv`）、删除等文件系统操作**只打印不执行**
- 不创建回滚快照目录（无任何落地改动）
- 前置检查、仓库克隆等只读流程照常执行

```bash
./bootstrap.sh --all --dry-run   # 预览全部模块将创建的软链
./bootstrap.sh --git --dry-run   # 仅预览 Git 模块
```

## 模块安装脚本

```bash
./zsh/install.sh        # Zsh + Homebrew + zinit + starship + zoxide
./vim/install.sh        # Vim + vim-plug
./emacs/install.sh      # Emacs + 包管理（Vertico/Corfu/Eglot）
./wezterm/install.sh    # WezTerm 配置
./ssh/install.sh        # SSH 配置（--gen-key 可生成本机密钥）
./python/install.sh     # Python + uv + 镜像 pip
./rust/install.sh       # Rust + rustup + 镜像
./brew/install.sh       # Homebrew bundle
./git/install.sh        # Git 全局配置
./tmux/install.sh       # Tmux + TPM
./editorconfig/install.sh  # .editorconfig 软链
./pwsh/install.sh         # PowerShell 配置（跨平台，无 pwsh 时自动跳过）
# Docker 是容器编排模块，无 install.sh，用 build.sh：
./docker/build.sh build dev  # 构建开发镜像
```

## 模块脚本标准结构

每个完整模块遵循 `_common.sh` 模式，包含以下脚本：

| 脚本 | 用途 |
|------|------|
| `install.sh` | 主安装入口，创建符号链接 + 安装依赖 |
| `check.sh` | 检查安装状态（不修改系统） |
| `_common.sh` | 共享函数（委托 lib/_module_loader.sh + lib/common.sh） |
| `uninstall.sh` | 卸载模块，删除符号链接（可选） |
| `clean.sh` | 清理缓存（保留配置，可选） |
| `upgrade.sh` | 升级模块依赖（可选） |
| `pin.sh` | 锁定版本（可选，如 zinit 插件版本） |
| `tools.list` | 工具清单（可选，python/rust 用） |
| `README.md` | 模块文档（必须） |

## SSH 模块特殊参数

```bash
./ssh/install.sh              # 仅安装配置
./ssh/install.sh --gen-key    # 生成本机 SSH 密钥（ed25519）
```

## 安装体检（check.sh）

10 个模块提供只读体检脚本，检查工具是否安装、软链/配置是否就位，**不修改系统**：

```bash
make doctor              # 一键跑全部 10 个模块的 check.sh 并汇总
bash git/check.sh        # 单独体检某个模块
make git-check           # 等价的 Makefile 入口（brew/zsh/vim/git/tmux/pwsh 等模块）
```

check.sh 发现失败项时以非零码退出（警告不影响退出码），因此已接入 CI。

## 验证安装

安装完成后可运行验证脚本：

```bash
make doctor              # 十模块安装体检（只读）
bash validate.sh         # 验证所有配置语法（10 模块）
bash tests/test_install.sh static   # 静态测试（CI 同套）
bash tests/test_install.sh all      # 完整测试（含动态模拟）

# Docker 集成测试（可选，需本地装 Docker）
./docker/build.sh test        # 运行集成测试（Ubuntu 24.04 容器）
./docker/build.sh shell dev   # 进入预装配置的交互式开发容器
```

详见 [测试与验证](/contribute/testing)。
