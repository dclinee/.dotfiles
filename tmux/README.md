# Tmux 模块

Tmux 终端复用器配置，Vim 风格快捷键，TPM 插件管理。

## 文件结构

```
tmux/
├── .tmux.conf    # Tmux 主配置
└── .gitignore
```

## 快速使用

### 安装

```bash
# 手动创建软链
ln -sf ~/.dotfiles/tmux/.tmux.conf ~/.tmux.conf

# 通过 bootstrap.sh
./bootstrap.sh --tmux
```

### 安装 TPM 插件管理器

```bash
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

在 Tmux 内按 `prefix + I` 安装配置中声明的所有插件。

## 配置特性

### 前缀键

- `Ctrl-a`（替代默认 `Ctrl-b`）
- `Ctrl-a` 发送前缀（在嵌套 Tmux 中使用）

### 快捷键

| 快捷键 | 功能 |
|--------|------|
| `|` | 垂直分屏 |
| `-` | 水平分屏 |
| `r` | 重载配置 |
| `h/j/k/l` | 窗格导航（Vim 风格） |
| `Ctrl-h/j/k/l` | 跨 Tmux/Vim/面板导航 |
| `z` | 窗格最大化/恢复 |
| `{` / `}` | 上/下一个窗格 |
| `C-a` (在嵌套中) | 发送实际前缀 |

### 基础设置

- **鼠标支持**：已启用
- **256 色/真彩**：`tmux-256color` 终端支持
- **历史记录**：100,000 行
- **窗口索引**：从 1 开始
- **零基索引**：已禁用

### 状态栏

使用 Powerline 风格主题，显示：会话名、窗口列表、主机名、时间。

### 插件

通过 TPM 管理（在 `.tmux.conf` 中声明）：
- `tmux-plugins/tpm` — 插件管理器
- `tmux-plugins/tmux-sensible` — 合理的默认配置
- `tmux-plugins/tmux-yank` — 系统剪贴板集成
- `tmux-plugins/tmux-resurrect` — 会话持久化
- `tmux-plugins/tmux-continuum` — 自动保存/恢复
- `tmux-plugins/tmux-prefix-highlight` — 前缀键高亮
- `tmux-plugins/tmux-open` — 打开 URL/文件

## 常用命令

```bash
tmux new -s mysession       # 新建会话
tmux ls                     # 列出会话
tmux attach -t mysession    # 附加到会话
tmux kill-session -t mysession  # 关闭会话
tmux kill-server            # 关闭所有会话
```

## 故障排除

### 真彩不生效

```bash
# 确保 .tmux.conf 中的终端设置
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",xterm-256color:Tc"

# 如果 tmux-256color 不可用
infocmp tmux-256color >/dev/null 2>&1 || tic -e tmux-256color
```

### Vim 与 Tmux 导航冲突

确保 Vim 使用 `vim-tmux-navigator` 或类似插件，与 `Ctrl-h/j/k/l` 绑定配合。
