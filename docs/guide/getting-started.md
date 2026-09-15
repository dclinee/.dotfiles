# 快速开始

## 前置要求

| 依赖 | 最低版本 | 用途 |
|------|---------|------|
| Git | 2.20+ | 克隆仓库 |
| Zsh | 5.9+ | 主 shell |
| curl | 任意 | 下载安装脚本 |

## 方式一：一键安装（推荐新机器）

```bash
# 直接远程执行（会自动克隆仓库到 ~/.dotfiles）
curl -fsSL https://raw.githubusercontent.com/dclinee/.dotfiles/main/bootstrap.sh | bash
```

或手动克隆后执行：

```bash
git clone https://github.com/dclinee/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./bootstrap.sh
```

支持选择性安装组件：

```bash
./bootstrap.sh --zsh      # 仅安装 Zsh
./bootstrap.sh --vim      # 仅安装 Vim
./bootstrap.sh --tmux     # 仅安装 Tmux
./bootstrap.sh --git      # 仅安装 Git 配置
./bootstrap.sh --brew     # 仅安装 Brew 包
./bootstrap.sh --all      # 安装全部（默认）
./bootstrap.sh --all --dry-run  # 预演：只打印将创建的软链/备份，不实际改动
```

:::tip 先预演再安装
首次安装或不确定改动范围时，建议先加 `--dry-run`。该模式导出 `DRY_RUN=true`
给所有子模块，`safe_symlink`/备份/删除等文件操作只打印不执行，也不会创建回滚快照。
:::

:::tip 国内用户
安装脚本已内置国内镜像降级策略，无需额外配置。详见 [国内镜像](/guide/mirror)。
:::

## 方式二：使用 Makefile

```bash
cd ~/.dotfiles
make install    # 一键安装所有配置
make zsh        # 仅安装 Zsh
make vim        # 仅安装 Vim
make tmux       # 仅安装 Tmux
make git        # 仅安装 Git 配置
make ssh        # 仅安装 SSH 配置
make brew       # 执行 brew bundle
make doctor     # 九模块安装体检（聚合 check.sh，只读不修改）
make help       # 查看所有可用命令
```

## 方式三：单独运行模块安装脚本

详见 [安装方式](/guide/installation)。

## 下一步

- 浏览 [模块总览](/modules/overview) 了解各模块功能
- 阅读 [架构文档](/architecture/overview) 理解系统设计
- 查看 [Zsh 模块](/modules/zsh) 学习自定义配置
