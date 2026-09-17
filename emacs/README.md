# Emacs 模块

GNU Emacs 的模块化配置框架，基于 [purcell/emacs.d](https://github.com/purcell/emacs.d) 改造，聚焦启动速度、跨平台一致性和国内加速。

## 目录结构

```
emacs/
├── early-init.el             # Emacs 27+ 预初始化（禁用自动 package-initialize）
├── init.el                   # 主入口（按依赖顺序 require lisp/*）
├── install.sh                # 安装脚本（装 Emacs + 链接配置 + 创建缓存目录）
├── _common.sh                # 模块公共加载器
├── custom.el                 # customize 接口生成的用户变量（不提交个人修改）
├── .dir-locals.el            # 目录局部变量（lisp/ 不 byte-compile）
├── .agignore                 # ag 搜索忽略规则
├── test-startup.sh           # 启动时间测试脚本
├── lisp/                     # 模块定义（82 个 init-*.el，按功能命名）
├── site-lisp/                # 本地扩展目录
└── elpa-MAJOR.MINOR/         # 版本化包目录（自动创建，gitignore）
```

## 模块分组

82 个 `init-*.el` 按功能分组加载（见 init.el 的 require 顺序）：

| 分组 | 文件 | 说明 |
|------|------|------|
| **基础** | `init-utils` `init-site-lisp` `init-elpa` `init-exec-path` | 包管理、PATH 设置 |
| **界面** | `init-frame-hooks` `init-xterm` `init-themes` `init-gui-frames` | 主题：doom-one / doom-one-light |
| **编辑** | `init-dired` `init-isearch` `init-grep` `init-uniquify` `init-editing-utils` `init-whitespace` `init-folding` | 搜索、目录、缩进 |
| **补全** | `init-minibuffer` `init-corfu` `init-hippie-expand` | **Vertico + Corfu**（Helm 已于 2026-09 弃用） |
| **项目** | `init-projectile` `init-vc` `init-git` `init-github` | projectile + magit |
| **LSP** | `init-eglot` `init-flymake` | Eglot 协议（非 lsp-mode） |
| **导航** | `init-avy` `init-recentf` `init-helpful` | avy 跳转、helpful 文档 |
| **Shell** | `init-vterm` | vterm 终端 |
| **语言** | `init-python` `init-rust` `init-javascript` `init-haskell` `init-elm` `init-purescript` `init-ruby` `init-rails` `init-sql` `init-ocaml` `init-j` `init-nim` `init-clojure` `init-clojure-cider` `init-common-lisp` `init-erlang` `init-php` `init-docker` `init-terraform` `init-nix` | 20+ 语言支持 |
| **标记** | `init-markdown` `init-csv` `init-textile` `init-org` `init-roam` | Org-agenda + Org-roam 双向链接 |
| **配置** | `init-toml` `init-yaml` `init-html` `init-css` `init-haml` `init-nxml` `init-http` | |
| **字体/图标** | `init-icons` | all-the-icons + nerd-icons |
| **平台** | `init-osx-keys` `init-windows` | macOS 键位、Windows 兼容 |
| **其他** | `init-benchmarking` `init-locales` `init-misc` `init-sessions` `init-deepseek` | DeepSeek AI 集成、启动计时 |

## 版本化包目录

不同 Emacs 版本的包互相隔离：

```
~/.config/emacs/               # 或 ~/.emacs.d/
├── elpa-29.3/                 # Emacs 29.3 安装的包
├── elpa-30.2/                 # Emacs 30.2 安装的包
├── init.el                    # 链接到 ~/.dotfiles/emacs/init.el
├── early-init.el              # 链接到 ~/.dotfiles/emacs/early-init.el
└── lisp/                      # 链接到 ~/.dotfiles/emacs/lisp/
```

升级 Emacs 后首次启动会自动创建新目录并安装包，旧版本目录可手动删除。

## 清华镜像包源

[init-elpa.el](https://github.com/dclinee/.dotfiles/blob/main/emacs/lisp/init-elpa.el) 配置：

```lisp
(setq package-archives
      '(("gnu"    . "https://mirrors.tuna.tsinghua.edu.cn/elpa/gnu/")
        ("nongnu" . "https://mirrors.tuna.tsinghua.edu.cn/elpa/nongnu/")
        ("melpa"  . "https://mirrors.tuna.tsinghua.edu.cn/elpa/melpa/")))

(setq package-archive-priorities
      '(("gnu"    . 100)   ; 最稳定
        ("nongnu" . 90)
        ("melpa"  . 0)))  ; 社区包，最后尝试
```

## 启动速度优化

| 优化 | 原理 |
|------|------|
| `early-init.el` | Emacs 27+ 在 package.el 前运行，设置 `package-enable-at-startup nil` |
| `gc-cons-threshold` | 启动时放大到 128MB，启动后恢复 20MB（[init.el:27-31](https://github.com/dclinee/.dotfiles/blob/main/emacs/init.el#L27-L31)） |
| `use-package-always-defer` | 延迟加载非核心包（[init.el:46](https://github.com/dclinee/.dotfiles/blob/main/emacs/init.el#L46)） |
| 包版本隔离 | 多版本 Emacs 用不同 elpa- 目录，避免重复解析 |
| 原生编译 (28+) | `native-comp-async` 自动编译 .el→.eln |

### 启动时间测试

```bash
cd ~/.dotfiles
./emacs/test-startup.sh
# 或 Emacs 内置
M-x emacs-init-time
```

正常启动时间：0.3 ~ 1.2 秒（取决于安装包数量和机器性能）

## 核心特性

### 补全体系（Vertico + Corfu + Consult）

2026-09 从 Helm 迁移到 Vertico，全系统一补全界面：

| 功能 | 包 | 按键 |
|------|---|------|
| 最小补全 UI | Vertico | 默认（M-x / C-x C-f / C-x b 等） |
| 内联补全 | Corfu | 编辑时弹出候选 |
| 搜索/跳转 | Consult | M-s l / M-s r / M-g g |
| 注解 | Marginalia | 候选右侧显示文件大小/时间 |
| Embark | Embark | C-c C-c 候选上批量操作 |

**已弃用**：Helm（2026-09），保留 `init-helm.el` 便于回退，确认稳定后卸载 helm 五个包。

### Git 集成

- **magit**：全屏 Git 界面（`M-x magit-status` 或 `C-x g`）
- **forge**：GitHub/GitLab PR/Issue 浏览
- **git-link**：复制远程仓库 URL

### 语言服务器

- **Eglot**：Emacs 内建 LSP 客户端（非 lsp-mode）
- **Flymake**：Emacs 内建诊断（非 Flycheck）
- 各语言 mode 自动激活 LSP（需对应语言服务器在 PATH 中）

### Org 模式

- **org-agenda**：GTD 任务管理
- **org-roam**：双向链接笔记（数据库不存在时可选加载）
- **org-babel**：内嵌代码块执行（Python 已配置 `org-babel-python-command`）

### AI 集成

- **init-deepseek.el**：DeepSeek Chat（基于 llm 包）

## 安装

```bash
cd ~/.dotfiles
./emacs/install.sh
# 或
bash bootstrap.sh --emacs
```

install.sh 功能：
1. 检测并安装 Emacs（brew / apt / dnf / pacman）
2. 链接配置到 `~/.config/emacs/`（XDG 路径，Emacs 27+）或 `~/.emacs.d/`（传统路径）
3. 创建缓存目录 `~/.cache/emacs/{backup,auto-save,url}`
4. 首次启动 Emacs 时自动安装所有包（清华镜像）

## 兼容性

| Emacs 版本 | 兼容性 | 备注 |
|------------|--------|------|
| 30.x (开发) | ✅ 最佳 | 原生编译改进 |
| 29.x (LTS) | ✅ | tree-sitter、pgtk |
| 28.x | ✅ 基础 | 缺少 tree-sitter 等功能 |
| 27.1 | ✅ 最低 | early-init.el 支持 |
| < 26.1 | ❌ | init.el 开头会报错退出 |

## 本地自定义

在 `lisp/` 下创建以下文件（.gitignore 不提交）：

| 文件 | 加载时机 | 用途 |
|------|---------|------|
| `init-local.el` | init.el 末尾 | 个人配置覆盖 |
| `init-preload-local.el` | init.el 早期 | 必须在 use-package 前设置的变量 |
| `custom.el` | init.el 末尾 | customize 接口生成的变量 |

## 故障排查

| 问题 | 解决 |
|------|------|
| 启动报错 `debug-on-error` | 在 init.el 取消注释 `(setq debug-on-error t)` 看堆栈 |
| 首次启动极慢（>5 分钟） | 包索引刷新慢，检查网络或换镜像源 |
| native-comp 报错 | 确认 build-essential 已装；临时禁用：`(setq native-comp-async-query-on-exit t)` |
| lsp-mode 冲突 | 已用 Eglot，不要同时装 lsp-mode 包 |
| Helm 回退 | 取消 init.el 中 `;; (require 'init-helm)` 的注释 |
