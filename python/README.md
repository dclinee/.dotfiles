# Python 模块

Python 开发环境的完整配置：多版本管理、包安装、虚拟环境、PEP 668 兼容。

## 目录结构

```
python/
├── install.sh                 # Python 模块安装主脚本
├── _common.sh                 # 公共函数（委托 lib/common.sh）
├── check.sh                   # 环境检查脚本
├── clean.sh                   # 清理旧版本缓存
├── upgrade.sh                 # 升级所有已安装包
├── pip.conf                   # pip 配置（国内镜像源）
├── uv.toml.template           # uv 配置模板（项目级）
├── pythonrc.py                # Python 启动脚本（~/.pythonrc）
├── pyproject.toml.template    # 新项目 pyproject 模板
├── requirements.txt           # 基础依赖（自动安装）
├── requirements-web.txt       # Web 开发（手动安装）
└── tools.list                 # 可通过 pipx 安装的 CLI 工具列表
```

## 依赖分层

| 层级 | 文件 | 安装方式 | 包含内容 |
|------|------|----------|----------|
| 基础 | `requirements.txt` | 自动安装 (install.sh) | requests, pyyaml, click, rich, tqdm, pytest, ruff, mypy, black, isort, virtualenvwrapper |
| Web 开发 | `requirements-web.txt` | 手动安装 | fastapi, uvicorn, requests-html, aiohttp |
| 数据处理 | `requirements-data.txt` | 手动安装 | numpy, pandas, polars |
| CLI 工具 | `tools.list` | pipx 安装 | yt-dlp, httpie, tldr, glances |

## 四层兜底安装策略

```
1. pip3 install --user -r requirements.txt
      ↓ 失败 (PEP 668 externally-managed)
2. pipx install --include-deps -r requirements.txt
      ↓ 无 pipx → 自动 brew/apt/dnf/pacman 安装 pipx
      ↓ 失败
3. 创建独立虚拟环境 ~/.cache/dotfiles-py-venv
   写入 ~/.local/share/dotfiles-py-path，zsh 启动自动入 PATH
      ↓ 失败
4. 提示用户手动选择：pipx 或 venv
```

## 虚拟环境自动切换

在 Zsh 配置中实现：

```
cd ~/code/myproject    # .venv 存在 → 自动激活
(myproject) ❯          # shell 提示符显示 venv 名称
cd ..                  # 离开目录 → 自动 deactivate
❯
```

- 进入含 `.venv` 的目录 → 自动激活
- 激活不同目录 venv → 自动切换（先 deactivate 旧的）
- 离开所有 .venv 目录 → 自动 deactivate
- 全局 python/pip 别名：仅非 venv 中才设置 `python=python3, pip=pip3`

## 国内镜像配置 (pip.conf)

```ini
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
extra-index-url = https://mirrors.aliyun.com/pypi/simple
trusted-host =
  pypi.tuna.tsinghua.edu.cn
  mirrors.aliyun.com

[install]
compile = no
```

## PEP 668 (externally-managed-environment) 兼容

Python 3.11+ Debian/Ubuntu 系统禁止全局安装包，本项目处理：

```bash
# 1. 检测是否外部管理环境
pip3 install --dry-run "pip" 2>&1 | grep -qi "externally-managed"

# 2. 外部管理 → 使用 pipx
pipx install --include-deps -r requirements.txt

# 3. 非外部管理 → 使用 --user
pip3 install --user -r requirements.txt
```

## 安装

```bash
cd ~/.dotfiles
./python/install.sh
```

安装脚本功能：
1. 检测 python3 / pip3，缺失时自动安装
2. 安装 uv（替代 pip 的高速包管理器）
3. 四层兜底安装 requirements.txt
4. 创建 `pip.conf` → `~/.pip/pip.conf` 符号链接
5. 创建 `pythonrc.py` → `~/.pythonrc` 符号链接
6. 按需创建虚拟环境目录 (`~/.virtualenvs`)

## 常用命令速查

| 功能 | 命令 |
|------|------|
| 安装 Python 包 | `pip install <pkg>` / `uv pip install <pkg>` |
| 全局 CLI 工具 | `pipx install <pkg>` |
| 创建虚拟环境 | `python3 -m venv .venv` |
| 激活虚拟环境 | `source .venv/bin/activate`（或 cd 进目录自动激活）|
| 格式化代码 | `ruff format file.py` / `black file.py` |
| 代码检查 | `ruff check file.py` / `mypy file.py` |
| 排序 import | `isort file.py` |
| 运行测试 | `pytest` |
| 查看包管理 | `pipx list` / `pip list` |
