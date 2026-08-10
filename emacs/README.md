# Emacs 模块

GNU Emacs 的模块化配置框架，聚焦启动速度和一致性体验。

## 目录结构

```
emacs/
├── early-init.el             # 启动前初始化（package 管理、加速）
├── init.el                   # 主入口（按编号加载 lisp/ 模块）
├── install.sh                # 安装脚本
├── test-startup.sh           # 启动时间测试脚本
├── lisp/                     # 模块定义（按编号排序加载）
│   ├── init-00-basics.el     # 基础选项（字体、备份、编码）
│   ├── init-01-packages.el   # 包管理（require-package 函数）
│   ├── init-02-ui.el         # 界面主题（doom-themes、mode-line）
│   ├── init-03-completion.el # 补全（company、ivy/vertico）
│   ├── init-04-editor.el     # 编辑器增强（paren、undo、whitespace）
│   ├── init-05-keybindings.el # 快捷键（evil、leader key）
│   ├── init-06-projects.el   # 项目管理（projectile、magit）
│   ├── init-07-programming.el # 通用编程（lsp、flycheck）
│   ├── init-08-python.el     # Python 开发（elpy、pyvenv、blacken）
│   ├── init-09-rust.el       # Rust 开发（rustic、cargo）
│   ├── init-10-org.el        # Org 模式（org-agenda、org-roam）
│   ├── init-11-shell.el      # Shell/终端（eshell、vterm）
│   └── init-99-final.el      # 最终设置（保存位置、钩子初始化）
└── elisa-MAJOR.MINOR/        # 版本化包目录（自动管理）
```

## 版本化包目录

```
~/.emacs.d/
├── elips-29.3/       # Emacs 29.3 安装的包
├── elips-30.0.50/    # Emacs 30 开发版安装的包
├── init.el           # 链接到 ~/.dotfiles/emacs/init.el
└── early-init.el     # 链接到 ~/.dotfiles/emacs/early-init.el
```

不同 Emacs 版本的包互相隔离，升级 Emacs 后无需清理冲突。

## 清华镜像包源

```lisp
(setq package-archives
      '(("gnu"    . "https://mirrors.tuna.tsinghua.edu.cn/elpa/gnu/")
        ("nongnu" . "https://mirrors.tuna.tsinghua.edu.cn/elpa/nongnu/")
        ("melpa"  . "https://mirrors.tuna.tsinghua.edu.cn/elpa/melpa/")))

(setq package-archive-priorities
      '(("gnu"    . 100)
        ("nongnu" . 90)
        ("melpa"  . 0)))
```

- 优先级：GNU (官方，最稳定) > Nongnu (官方维护非自由) > MELPA (社区)

## require-package 函数

```lisp
(defun require-package (package &optional min-version no-refresh)
  "安装 PACKAGE（可选 MIN-VERSION）。如 NO-REFRESH 不刷新索引。"
  (or (package-installed-p package min-version)
      ;; nil min-version 跳过版本比较
      (if (or (null min-version) ...)
          ...
          )))
```

- 支持 nil min-version（无需版本比较时跳过）
- 不存在 → 自动安装
- 自动处理 package 索引刷新

## 启动速度优化

| 优化 | 原理 |
|------|------|
| `early-init.el` 设置 | 在 package.el 前运行，关闭无用图形元素 |
| `gc-cons-threshold` | 启动时放大到 100MB，启动后恢复 8MB |
| 包懒加载 `:defer t` | use-package 延迟加载非核心包 |
| 包版本隔离 | 多版本 Emacs 用不同 elpa- 目录，避免重复解析 |
| 原生编译 (28+) | `native-comp-async` 自动编译 .el→.eln |

### 启动时间测试

```bash
cd ~/.dotfiles
./emacs/test-startup.sh
# 或 Emacs 内置
M-x emacs-init-time
```

正常启动时间: 0.3 ~ 1.2 秒（取决于安装包数量和机器性能）

## 核心特性

### 🎨 界面主题

- 默认配色: doom-one (dark) / doom-one-light (light)
- 模式行: doom-modeline + all-the-icons
- 图标: all-the-icons / nerd-icons

### ⌨️ Evil 模式 (Vim 风格)

```
<leader> w   → 保存
<leader> q   → 退出
<leader> ff  → 查找文件 (projectile)
<leader> fr  → 最近文件
<leader> ss  → 搜索字符串 (ripgrep)
<leader> bb  → 切换 buffer
<leader> pp  → 切换项目
gcc          → 注释一行 (evil-nerd-commenter)
```

### 🐍 Python 开发

```
C-c C-c      → 发送行/段落到 Python shell
C-c C-r      → 运行 pytest 当前文件
C-c C-f      → 格式化 (blacken)
C-c C-v      → pyvenv 激活虚拟环境
M-?          → 查找定义 (elpy/jedi)
```

### 🦀 Rust 开发

```
C-c C-c C-c  → cargo run
C-c C-c C-t  → cargo test
C-c C-c C-f  → cargo fmt
C-c C-c C-l  → cargo clippy
C-c C-c C-a  → cargo add
```

### 📋 Org 模式

- org-agenda: GTD 任务管理
- org-roam: 双向链接笔记
- org-babel: 内嵌代码块执行

## 安装

```bash
cd ~/.dotfiles
./emacs/install.sh
```

安装脚本功能：
1. 检测并安装 Emacs（brew / apt / dnf / pacman）
2. 创建 `early-init.el` → `~/.emacs.d/early-init.el` 符号链接
3. 创建 `init.el` → `~/.emacs.d/init.el` 符号链接
4. 首次启动 Emacs 时自动安装所有包（清华镜像）
5. 创建 elpa-MAJOR.MINOR 版本化目录

## 兼容性

| Emacs 版本 | 兼容性 | 备注 |
|------------|--------|------|
| 29.x (LTS) | ✅ 最佳 | 原生 JSON、tree-sitter、pgtk |
| 30.x (开发) | ✅ | 原生编译改进、Eglot 增强 |
| 28.x | ⚠️ 基础 | 缺少 tree-sitter 等功能 |
| < 27.x | ❌ | 不支持 |
