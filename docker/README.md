# Dotfiles Docker 模块

集中管理容器化开发环境配置，用于本地开发测试 + CI 集成测试验证。

## 目录结构

```
docker/
├── Dockerfile              # 主多阶段构建（基于 Ubuntu 24.04）
├── Dockerfile.ubuntu       # Ubuntu 24.04 测试矩阵
├── Dockerfile.debian       # Debian 12 测试矩阵
├── Dockerfile.fedora       # Fedora 40 测试矩阵
├── docker-compose.yml      # Compose 编排（多发行版 + dev + validate + test）
├── build.sh                # 统一操作脚本（build/up/down/logs/clean/shell/test/validate）
├── _common.sh              # 公共函数（源 lib/common.sh + 镜像源定义）
├── .env.example            # 环境变量模板
└── README.md               # 本文档
.dockerignore               # 根目录忽略规则（构建 context 用）
```

## 快速开始

### 1. 构建镜像

```bash
# 构建 dev 镜像（默认 USTC 镜像加速）
docker build -f docker/Dockerfile -t dotfiles-dev .

# 或用 build.sh
./docker/build.sh build dev

# 官方源（禁用所有镜像）
NO_MIRROR=1 docker build -f docker/Dockerfile -t dotfiles-dev .
```

### 2. 启动开发容器

```bash
# 进入交互式 zsh（挂载本地仓库，实时编辑）
docker compose run --rm dev
# 或
./docker/build.sh shell dev
```

### 3. 在特定发行版上测试

```bash
# Ubuntu 24.04
docker compose run --rm --profile test ubuntu
./docker/build.sh shell ubuntu

# Debian 12
docker compose run --rm --profile test debian

# Fedora 40
docker compose run --rm --profile test fedora
```

### 4. 运行测试

```bash
# 静态验证（validate.sh）
docker compose run --rm --profile validate validate
./docker/build.sh validate

# 集成测试（test_integration.sh）
docker compose run --rm --profile test-run test
./docker/build.sh test

# 在指定发行版容器里跑集成测试
./docker/build.sh test ubuntu
./docker/build.sh test debian
```

### 5. 清理

```bash
# 停止容器
./docker/build.sh down

# 彻底清理（含镜像 + 卷）
./docker/build.sh clean
```

## Dockerfile 设计

### 多阶段构建

| Stage | 内容 | 作用 |
|---|---|---|
| `base` | apt 换源 → 装所有工具链 → 建非 root 用户 | 工具链基础镜像 |
| `final` | COPY dotfiles → 跑 bootstrap.sh --all | 预装完整配置的开发容器 |

关键设计：
- **非 root 用户**（默认 `dotfiles-dev`，UID 1000），sudo 仅允许 apt/dpkg
- **`NO_BREW=1`** 跳过 brew 模块（容器内 Homebrew 体验差，工具从 apt 安装）
- **apt 镜像换源**通过 build-arg `APT_MIRROR` 控制，与 dotfiles 自身镜像机制解耦

### 镜像大小优化

```dockerfile
# 只装必要依赖，--no-install-recommends
apt-get install -y --no-install-recommends ... && rm -rf /var/lib/apt/lists/*

# .dockerignore 排除 elpa/node_modules/归档等无关文件
COPY --chown=dotfiles-dev:dotfiles-dev . /home/.../.dotfiles
```

## 国内镜像加速

三层加速，均可通过 `NO_MIRROR=1` 一键禁用：

| 层 | 配置位置 | 镜像源 |
|---|---|---|
| **apt 包** | Dockerfile build-arg `APT_MIRROR` | `https://mirrors.ustc.edu.cn/ubuntu` |
| **dotfiles 内部** | `NO_MIRROR` 环境变量 | brew/pip/cargo/rustup 各自走 USTC |
| **Docker Hub** | daemon.json `registry-mirrors` | `https://docker.1ms.run` / `https://hub-mirror.c.163.com` |

配置 Docker Hub 镜像（`/etc/docker/daemon.json`）：

```json
{
  "registry-mirrors": [
    "https://docker.1ms.run",
    "https://hub-mirror.c.163.com"
  ]
}
```

## Compose 服务说明

| Service | Profile | 用途 | 挂载 |
|---|---|---|---|
| `dev` | — | 日常开发，交互式 zsh | 本地仓库 + 持久 home 卷 |
| `ubuntu` | `test` | Ubuntu 24.04 测试 | 独立 home 卷 |
| `debian` | `test` | Debian 12 测试 | 独立 home 卷 |
| `fedora` | `test` | Fedora 40 测试 | 独立 home 卷 |
| `validate` | `validate` | 运行 validate.sh | 本地仓库挂载 |
| `test` | `test-run` | 运行 test_integration.sh | 本地仓库挂载 |

## Makefile 集成

```makefile
# 已集成到项目 Makefile
make docker-build     # 构建 dev 镜像
make docker-up        # 启动 dev 容器（交互式）
make docker-test      # 运行集成测试
make docker-validate  # 运行静态验证
make docker-clean     # 清理所有 Docker 资源
```

## 注意事项

1. **不要把真实密钥提交进镜像**。`.dockerignore` 已排除 `**/.pem`、`**/.env.local`、`git/.gitconfig.local`、`ssh/config.local`。
2. **Emacs elpa 需要首次启动**时联网下载（容器内运行 `emacs --batch` 即可）。
3. **WezTerm** 是 GUI 应用，不会在容器内运行；tmux/vim/emacs-nox/zsh 可正常使用。
4. **Homebrew 在容器内体验差**，默认跳过；如需测试 brew 模块，请在宿主机运行。
5. **build.sh 需要 docker compose v2**（`docker compose version`），v1 (`docker-compose`) 会自动 fallback。

## 常见问题

**Q: 构建时 apt 下载超时？**
A: 检查网络或换用其他镜像源：`APT_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/ubuntu NO_MIRROR=0 docker build ...`

**Q: 容器内 emacs 首次启动很慢？**
A: 正常，elpa 需要下载包。可预编译：`docker run --rm dotfiles-dev emacs --batch -f batch-byte-compile lisp/*.el`

**Q: dev 容器里修改配置后宿主机没生效？**
A: 检查 build.sh 是否用 `:cached` 挂载；`:ro` 只读挂载则容器内修改不回传。当前 compose 配置是 `:cached`。

**Q: 如何添加新的发行版测试？**
A: 创建 `docker/Dockerfile.<distro>`（参考 ubuntu/debian/fedora 三份的模式），在 `docker-compose.yml` 里加一个 `profiles: ["test"]` 的 service。
