# Wezterm 模块

跨平台终端模拟器配置，基于模块化 Lua 加载器，对齐 vim/zsh 的分层模式。

## 文件结构

```
wezterm/
├── wezterm.lua                  # 入口文件（平台检测 + 模块加载器）
├── install.sh                   # 安装脚本（创建 .wezterm.lua 软链）
├── check.sh                     # 环境体检（核心工具/软链/语法/权限）
├── uninstall.sh                 # 卸载（移除软链 + 可选 purge 本体）
├── _common.sh                   # 内部公共加载器
├── core/                        # 核心配置（按数字前缀排序加载）
│   ├── 00_basic.lua             # 基础外观/窗口/标签/光标/性能
│   ├── 01_keybindings.lua       # 快捷键/键表/鼠标绑定
│   ├── 02_colors.lua            # 标签栏颜色配置
│   ├── 03_events.lua            # 事件处理（状态栏/配色切换/重载通知）
│   └── 04_domains.lua           # 域配置（unix_domains / SSH 域）
├── platform/                    # 平台特定配置
│   ├── linux.lua                # Linux 配置
│   ├── macos.lua                # macOS 配置
│   └── windows.lua              # Windows 配置
└── README.md                    # 本文件
```

## 模块加载机制

`wezterm.lua` 入口文件负责：
1. **平台检测**：根据 `wezterm.target_triple` 判断当前系统
2. **模块加载器**：按文件名排序加载 `core/*.lua`，每个文件返回配置表
3. **配置合并**：数组型追加，字典型按键合并
4. **平台覆盖**：加载 `platform/<os>.lua` 覆盖核心配置

## 快速使用

### 安装

```bash
# 通过 Makefile
make wezterm

# 直接执行
./wezterm/install.sh

# 通过 bootstrap.sh
./bootstrap.sh --wezterm
```

### 日常维护

```bash
make wezterm-check       # 环境体检
make wezterm-uninstall   # 卸载配置（不含本体）
```

或直接执行脚本：

```bash
./wezterm/check.sh
./wezterm/uninstall.sh              # 仅移除软链
./wezterm/uninstall.sh --purge       # 彻底卸载（含本体）
./wezterm/uninstall.sh --dry-run     # 预览操作
```

## 体检项

`check.sh` 检查以下项目：
- **核心工具**：wezterm 是否安装
- **配置软链**：`.wezterm.lua` 软链正确性
- **配置语法**：`luac` 检查所有 `.lua` 文件语法（如 luac 可用）
- **平台配置**：对应平台的配置文件是否存在
- **权限排查**：`.dotfiles` 目录属主检查

## 配置文件说明

| 文件 | 说明 |
|------|------|
| `core/00_basic.lua` | 字体、窗口、标签、光标、性能设置 |
| `core/01_keybindings.lua` | 快捷键、Leader 键表、鼠标绑定 |
| `core/02_colors.lua` | 标签栏 Tokyo Night 配色 |
| `core/03_events.lua` | 状态栏（电池+时间）、配色切换、重载通知 |
| `core/04_domains.lua` | unix_domains 配置 + 可选 SSH 域 |
| `platform/linux.lua` | Linux 专属配置（字体等） |
| `platform/macos.lua` | macOS 专属配置 |
| `platform/windows.lua` | Windows 专属配置 |

## 配色切换

在 Wezterm 中按 `Leader + r` 循环切换配色方案：
Tokyo Night → Dracula → One Dark → Solarized Dark → Catppuccin Mocha → Gruvbox Dark → Monokai Pro → Nord

## 域配置

默认配置 `unix_domains`（本地复用），SSH 域通过环境变量可选启用：

```bash
export WEZTERM_SSH_SERVER="user@remote-host"
```

## 自定义

各 `core/*.lua` 和 `platform/*.lua` 文件独立修改即可，无需修改入口文件。
