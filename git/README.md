# Git 模块

Git 全局配置，预配置常用别名、颜色、pager 模板，支持 `~/.gitconfig.local` 本地覆盖。

## 文件结构

```
git/
├── .gitconfig         # Git 全局配置模板（别名、颜色、pager、协议）
├── .gitignore_global  # 全局忽略规则
└── .gitattributes     # 全局属性（自动换行等）
```

## 快速使用

### 安装

```bash
# 手动创建软链
ln -sf ~/.dotfiles/git/.gitconfig ~/.gitconfig
ln -sf ~/.dotfiles/git/.gitignore_global ~/.gitignore_global

# 通过 bootstrap.sh
./bootstrap.sh --git
```

### 配置用户信息

**重要**：不要在 `.gitconfig` 中硬编码个人信息。请在 `~/.gitconfig.local` 中配置：

```bash
cat > ~/.gitconfig.local << 'EOF'
[user]
    name = Your Name
    email = your@email.com
EOF
```

`bootstrap.sh` 安装时会自动创建此模板。

## 配置特性

### 核心设置

| 设置 | 值 | 说明 |
|------|---|------|
| `core.editor` | `nvim` | 使用 Neovim |
| `core.pager` | `less -FRX` | 支持颜色和滚动 |
| `core.autocrlf` | `input` | 自动转换换行符 |
| `core.quotepath` | `false` | 不转义 Unicode 文件名 |
| `init.defaultBranch` | `main` | 默认分支名 |

### 常用别名

```bash
git aliases       # 查看所有别名
```

| 别名 | 命令 | 说明 |
|------|------|------|
| `g` | `git` | 快速调用 |
| `ga` | `git add` | 添加文件 |
| `gst` | `git status` | 查看状态 |
| `gco` | `git checkout` | 切换分支 |
| `gcob` | `git checkout -b` | 创建并切换分支 |
| `gbr` | `git branch` | 查看分支 |
| `gl` | `git log --oneline --graph --decorate` | 图形化日志 |
| `gd` | `git diff` | 查看差异 |
| `gdc` | `git diff --cached` | 查看暂存区差异 |
| `gu` | `git reset --soft HEAD~1` | 撤销最后一次提交 |
| `gcm` | `git commit -m` | 快速提交 |
| `gca` | `git commit --amend` | 修改上一次提交 |
| `gp` | `git push` | 推送 |
| `gpf` | `git push --force-with-lease` | 安全强推 |
| `gpl` | `git pull --rebase` | 拉取并变基 |
| `grb` | `git rebase -i` | 交互式变基 |
| `gra` | `git rebase --abort` | 中止变基 |
| `grc` | `git rebase --continue` | 继续变基 |
| `gs` | `git stash` | 暂存 |
| `gsp` | `git stash pop` | 恢复暂存 |
| `gsl` | `git stash list` | 列出暂存 |
| `gsu` | `git stash -u` | 暂存含未追踪文件 |
| `gb` | `git branch` | 分支操作 |
| `bd` | `git branch -d` | 删除分支 |
| `cp` | `git cherry-pick` | 拣选提交 |
| `cl` | `git clone` | 克隆仓库 |
| `incoming` | `git log ..@{upstream}` | 查看远程新增 |
| `outgoing` | `git log @{upstream}..` | 查看本地待推送 |

### 颜色配置

启用 Git 全彩输出，区分：
- 已暂存 / 未暂存 / 未追踪
- 变更 / 删除 / 新增文件
- 分支 / 标签 / HEAD

### Pager 配置

默认使用 `less` 作为 pager，配置支持颜色保留和滚动：

```bash
git config --global core.pager 'less -FRX'
```

## 全局忽略

`.gitignore_global` 忽略跨项目的临时文件：
- 编辑器备份（`*~`, `*.swp`）
- 系统文件（`.DS_Store`, `Thumbs.db`）
- 环境目录（`.venv`, `node_modules`）
- 缓存目录（`.cache`, `.pytest_cache`）

## 本地覆盖

所有配置可在 `~/.gitconfig.local` 中覆盖：

```ini
# ~/.gitconfig.local 示例
[user]
    name = Your Name
    email = your@email.com

[core]
    editor = vim

[alias]
    myalias = custom-command
```

## 查看当前配置

```bash
git config --list          # 列出所有配置
git config --show-origin   # 显示配置来源文件
git config --show-origin --list
```
