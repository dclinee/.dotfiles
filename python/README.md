# Python 模块

Python 开发环境配置与维护工具集，基于 [uv](https://docs.astral.sh/uv/) 高性能包管理器。

## 文件结构

```
python/
├── install.sh                   # 部署主入口：安装 uv、配置镜像、虚拟环境、CLI 工具
├── uninstall.sh                 # 卸载：移除配置软链、清理环境变量，可选卸载 uv 本体
├── check.sh                     # 环境体检：版本校验、源检测、权限排查
├── upgrade.sh                   # 一键升级：uv 自身 + venv 依赖 + CLI 工具
├── clean.sh                     # 清理：pip/uv 缓存、__pycache__、冗余工具
├── pin.sh                       # 版本固化：记录当前版本，支持恢复和对比
├── _common.sh                   # 内部公共加载器（加载 lib/ 库 + 工具函数）
├── uv.toml.template             # uv 全局配置模板（镜像源、缓存、并发）
├── pip.conf                     # pip 全局配置（向后兼容）
├── pyproject.toml.template      # 代码质量工具配置（black/ruff/mypy）
├── tools.list                   # Python 全局 CLI 工具清单（包名|版本）
├── .python-version              # 默认 Python 版本
├── pythonrc.py                  # 交互式 shell 增强配置
├── requirements.txt             # 基础依赖
├── requirements-dev.txt         # 开发依赖（可选）
├── requirements-data.txt        # 数据科学依赖（可选）
├── requirements-web.txt         # Web 开发依赖（可选）
└── README.md                    # 本文件
```

## 快速使用

### 安装

```bash
# 通过 Makefile
make python

# 直接执行
./python/install.sh

# 仅安装 uv
./python/install.sh --uv-only

# 预览操作
./python/install.sh --dry-run

# 通过 bootstrap.sh
./bootstrap.sh --python
```

### 日常维护

```bash
make python-check      # 环境体检
make python-upgrade    # 一键升级
make python-clean      # 清理缓存
make python-uninstall  # 卸载配置
make python-pin        # 固化版本
```

或直接执行脚本：

```bash
./python/check.sh
./python/upgrade.sh
./python/clean.sh
./python/uninstall.sh
./python/pin.sh
```

## 脚本说明

### install.sh

部署主入口，执行以下操作：
1. 安装 uv（高性能 Python 包管理器，优先 pipx/brew，回退 curl 安装）
2. 链接 uv 配置（镜像源、缓存、并发下载）
3. 链接 pip 配置（向后兼容）
4. 链接 pythonrc.py（交互增强）
5. 链接 pyproject.toml（代码质量工具配置）
6. 创建虚拟环境 `~/.venv-dotfiles`（回退链：普通创建 → --clear → --force → python3 -m venv）
7. 从 `tools.list` 安装 CLI 工具（uv tool install）

### uninstall.sh

| 选项 | 说明 |
|------|------|
| （默认） | 移除配置软链 + 清理 shell 引用 |
| `--tools` | 额外卸载 CLI 工具 |
| `--venv` | 额外删除 venv（~/.venv-dotfiles） |
| `--purge` | 彻底卸载 uv（需确认） |

### check.sh

环境体检，检查以下项目：
- 核心工具版本（python3 / uv / pip3 / pipx）
- 镜像源配置（uv + pip）
- 虚拟环境状态
- 配置文件软链正确性
- CLI 工具安装状态
- 目录权限排查

### upgrade.sh

| 选项 | 说明 |
|------|------|
| （默认） | 升级 uv 自身 + venv 依赖 + CLI 工具 |
| `--self` | 仅升级 uv 自身 |
| `--deps` | 仅升级 venv 依赖 |
| `--tools` | 仅升级 CLI 工具 |

### clean.sh

| 选项 | 说明 |
|------|------|
| （默认） | 清理 pip/uv 缓存 + __pycache__ + venv .pyc |
| `--deep` | 深度清理（含卸载未在 tools.list 中的工具） |
| `--dry-run` | 预览将清理的内容 |

### pin.sh

| 选项 | 说明 |
|------|------|
| （默认） | 固化当前版本到 `versions.lock` |
| `--restore` | 从 `versions.lock` 恢复版本 |
| `--diff` | 对比当前版本与锁定版本 |

## tools.list 格式

```
# 格式: 包名|版本
#   版本留空 = 安装最新稳定版
#   版本指定 = uv tool install --version <ver>
#   以 # 开头的行为注释，自动跳过
#
# 工具分类:
#   代码格式化: black
#   Linter: ruff
#   类型检查: mypy
#   增强 REPL: ipython
#   HTTP 客户端: httpie
#   Git hook: pre-commit
#   文档工具: mdformat
```

## 配置文件说明

| 文件 | 链接目标 | 说明 |
|------|----------|------|
| `uv.toml.template` | `~/.config/uv/uv.toml` | uv 镜像源、缓存目录、并发数 |
| `pip.conf` | `~/.pip/pip.conf` | pip 镜像源（向后兼容） |
| `pyproject.toml.template` | `~/.pyproject.toml` | black/ruff/mypy 全局配置（新项目复制到项目根） |
| `pythonrc.py` | `~/.pythonrc.py` | 交互式 shell 增强 |
| `.python-version` | （项目级复制） | 默认 Python 版本 |

## 镜像源

默认使用清华大学 TUNA 镜像，备选：
- 阿里云: `https://mirrors.aliyun.com/pypi/simple/`
- USTC: `https://pypi.mirrors.ustc.edu.cn/simple/`

切换镜像：编辑 `uv.toml.template` 中的 `index-url` 字段。

## 回退链

当 uv 不可用时，自动回退到以下方式：
1. uv（最快） → 2. pipx → 3. pip3 --user → 4. python3 -m venv
