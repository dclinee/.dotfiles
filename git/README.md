# Git 模块

Git 全局配置，预配置常用别名、颜色、pager、GPG 签名、GitHub CLI 集成，支持 `~/.gitconfig.local` 本地覆盖。

## 文件结构

```
git/
├── .gitconfig         # Git 全局配置模板（别名、颜色、pager、协议、GPG、凭证）
├── .gitignore_global  # 全局忽略规则
├── .gitattributes     # 全局属性（自动换行、语言标记）
├── gh_config.yml      # GitHub CLI 配置模板
└── hooks/             # 公共 Git Hooks 模板
    └── README.md      # Hooks 使用说明
```

## 快速使用

### 安装

```bash
# 手动创建软链
ln -sf ~/.dotfiles/git/.gitconfig ~/.gitconfig
ln -sf ~/.dotfiles/git/.gitignore_global ~/.gitignore_global
ln -sf ~/.dotfiles/git/.gitattributes ~/.gitattributes

# 设置 GitHub CLI 配置
mkdir -p ~/.config/gh
cp ~/.dotfiles/git/gh_config.yml ~/.config/gh/config.yml

# 可选：设置公共 hooks 目录
mkdir -p ~/.git/hooks
cp ~/.dotfiles/git/hooks/* ~/.git/hooks/
# 或使用 git config:
git config --global core.hooksPath ~/.dotfiles/git/hooks

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

# 可选：启用 GPG 签名
[gpg]
    signingkey = YOUR_GPG_KEY_ID

[commit]
    gpgsign = true

[tag]
    gpgsign = true
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
| `core.attributesfile` | `~/.dotfiles/git/.gitattributes` | 全局属性文件 |
| `init.defaultBranch` | `main` | 默认分支名 |
| `protocol.version` | `2` | Git 协议版本，提升效率 |

### 凭证安全

默认使用 **内存缓存**（`credential.helper = cache`，有效期 1 小时），避免明文存储 Token/密码。

```bash
# macOS 推荐使用系统钥匙链
git config --global credential.helper osxkeychain

# Linux 推荐使用 libsecret（需安装）
git config --global credential.helper /usr/share/doc/git/contrib/credential/libsecret/git-credential-libsecret

# 查看当前凭证
git credential fill <<< "protocol=https
host=github.com"
```

### GPG 签名

预配置 GPG 程序路径，需在 `~/.gitconfig.local` 中设置具体密钥：

```bash
# 生成 GPG 密钥
gpg --full-generate-key

# 获取密钥 ID
gpg --list-secret-keys --keyid-format LONG

# 在 ~/.gitconfig.local 中添加
# [gpg]
#     signingkey = ABCD1234
# [commit]
#     gpgsign = true
```

### 常用别名

```bash
git aliases       # 查看所有别名
```

#### 基础操作

| 别名 | 命令 | 说明 |
|------|------|------|
| `co` | `checkout` | 检出 |
| `ci` | `commit` | 提交 |
| `st` | `status -sb` | 短状态 |
| `br` | `branch -vv` | 分支详情 |
| `sw` | `switch` | 切换 |

#### 日志与差异

| 别名 | 命令 | 说明 |
|------|------|------|
| `lg` | `log --oneline --graph -20` | 图形化日志 |
| `lga` | `log --oneline --graph --all -20` | 全分支日志 |
| `ll` | 格式化日志 | 含相对时间 |
| `lll` | 格式化日志+文件 | 含变更文件 |
| `d` | `diff` | 查看差异 |
| `dc` | `diff --cached` | 暂存区差异 |
| `ds` | `diff --staged` | 暂存区差异 |

#### 暂存与提交

| 别名 | 命令 | 说明 |
|------|------|------|
| `unstage` | `reset HEAD --` | 取消暂存 |
| `amend` | `commit --amend --no-edit` | 修改提交 |
| `amend-new` | `commit --amend` | 修改提交（编辑消息） |
| `uncommit` | `reset --soft HEAD~1` | 撤销最后一次提交 |
| `last` | `log -1 HEAD` | 查看上一次提交 |

#### 分支与远程

| 别名 | 命令 | 说明 |
|------|------|------|
| `bd` | `branch -d` | 删除分支 |
| `bD` | `branch -D` | 强制删除分支 |
| `bm` | `branch -m` | 重命名分支 |
| `ba` | `branch -a` | 列出所有分支 |
| `ra` | `remote add` | 添加远程 |
| `rr` | `remote rm` | 移除远程 |
| `rv` | `remote -v` | 查看远程 |
| `ru` | `remote update` | 更新远程 |

#### GitHub CLI 集成（需安装 `gh`）

| 别名 | 命令 | 说明 |
|------|------|------|
| `ghpr` | `gh pr view --web` | 查看当前 PR |
| `ghprlist` | `gh pr list` | 列出 PR |
| `ghissue` | `gh issue view --web` | 查看 Issue |
| `ghissuelist` | `gh issue list` | 列出 Issue |
| `ghrepo` | `gh repo view --web` | 查看仓库 |
| `ghprcreate` | `gh pr create` | 创建 PR |
| `ghrelease` | `gh release list` | 列出 Release |
| `ghworkflow` | `gh workflow list` | 列出 Workflow |
| `ghruncancel` | `gh run cancel` | 取消 Workflow Run |
| `ghrerun` | `gh run rerun` | 重新运行 Workflow |
| `ghstatus` | 仓库状态摘要 | 名称/星标/Fork 数 |
| `ghauth` | `gh auth status` | 认证状态 |
| `ghlabels` | `gh label list` | 列出标签 |
| `ghmilestones` | `gh milestone list` | 列出里程碑 |

### 颜色配置

启用 Git 全彩输出，区分：
- 已暂存 / 未暂存 / 未追踪
- 变更 / 删除 / 新增文件
- 分支 / 标签 / HEAD

## 全局属性

`.gitattributes` 为常见文件类型配置统一的换行符：
- Shell 脚本、配置文件、编程语言 → `eol=lf`
- Windows 批处理文件 → `eol=crlf`
- 二进制文件（图片、压缩包、字体等）→ `binary`
- 语言标记 → `linguist-detectable=true`

## 全局忽略

`.gitignore_global` 忽略跨项目的临时文件：
- 编辑器备份（`*~`, `*.swp`）
- 系统文件（`.DS_Store`, `Thumbs.db`）
- 环境目录（`.venv`, `node_modules`）
- 缓存目录（`.cache`, `.pytest_cache`）
- 密钥文件（`*.pem`, `*.key`, `*.crt`）

## Git Hooks

`hooks/` 目录提供公共 hooks 模板，需手动启用：

```bash
# 设置全局 hooks 目录
git config --global core.hooksPath ~/.dotfiles/git/hooks
```

包含的 hooks：
- **pre-commit**: 检查尾随空格和 CRLF 行尾
- **commit-msg**: 检查提交信息长度和格式
- **pre-push**: 阻止直接推送到 main/master 分支

## 本地覆盖

所有配置可在 `~/.gitconfig.local` 中覆盖：

```ini
# ~/.gitconfig.local 示例
[user]
    name = Your Name
    email = your@email.com

[core]
    editor = vim

[credential]
    helper = osxkeychain   # macOS

[gpg]
    signingkey = YOUR_KEY_ID

[alias]
    myalias = custom-command
```

## 查看当前配置

```bash
git config --list          # 列出所有配置
git config --show-origin   # 显示配置来源文件
git config --show-origin --list
git aliases               # 查看所有别名
git whoami                # 查看 user.name / user.email
```
