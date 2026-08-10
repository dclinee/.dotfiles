# WezTerm 模块

WezTerm（GPU 加速的跨平台终端模拟器）的模块化 Lua 配置框架。

## 目录结构

```
wezterm/
├── wezterm.lua           # 主入口（pcall 安全加载）
├── install.sh            # 安装脚本
├── uninstall.sh          # 卸载脚本
├── check.sh              # 配置检查脚本
├── _common.sh            # 公共函数
├── core/                 # 核心配置模块
│   ├── 00_basic.lua      # 基础设置（字体、窗口、颜色主题）
│   ├── 01_keybindings.lua # 快捷键绑定
│   ├── 02_colors.lua     # 配色方案（含动态浅色/深色）
│   ├── 03_events.lua     # 事件回调（启动、关闭、热加载）
│   └── 04_domains.lua    # 多工作域（SSH、WSL、本地）
└── platform/             # 平台特定配置
    ├── linux.lua         # Linux 专属（字体、图标）
    ├── macos.lua         # macOS 专属（触控板、mac 标题栏）
    └── windows.lua       # Windows 专属（WSL 集成、字体）
```

## Lua 配置加载安全

```lua
local ok, err = pcall(dofile, file_path)
if not ok then
  wezterm.log_error("加载失败: " .. tostring(err))
  -- 不中断启动，仅记录错误
end
```

- 所有子模块通过 `pcall(dofile)` 加载
- 单个模块失败不阻止 WezTerm 启动
- 错误记录到 WezTerm 日志

## 核心特性

### 🎨 动态配色

```lua
function scheme_for_appearance(appearance)
  if appearance:find("Dark") then
    return "Tokyo Night Night"
  else
    return "Tokyo Night Day"
  end
end
```

- 跟随系统浅色/深色模式自动切换
- 内置 N 种配色方案选择

### 🎯 字体渲染

| 平台 | 推荐字体 | 配置 |
|------|----------|------|
| Linux | JetBrainsMono Nerd Font | `{ family = "JetBrains Mono", weight = "Regular" }` |
| macOS | MesloLGS NF / SF Mono | 含 Apple 符号回退 |
| Windows | CaskaydiaCove Nerd Font | 含 CJK 字符回退 |

- 支持 CJK / 图标 / Powerline 字符渲染
- 含 Nerd Font 检测：无字体时纯文本降级

### ⌨️ 快捷键

| 快捷键 | 功能 |
|--------|------|
| `Ctrl+Shift+t` | 新建标签页 |
| `Ctrl+Shift+w` | 关闭标签页 |
| `Ctrl+Shift+h` | 水平分割 Pane |
| `Ctrl+Shift+v` | 垂直分割 Pane |
| `Alt+1..9` | 切换第 1-9 个 Tab |
| `Ctrl+Shift+PageUp/Down` | 切换透明度 |
| `Ctrl+Shift+r` | 热加载配置（reload） |
| `Ctrl+Shift+f` | 搜索历史输出 |
| `Ctrl+Shift+c / v` | 复制 / 粘贴 |

### 📺 多域管理

```
"local"  → 本地 shell（默认）
"WSL"    → Windows Subsystem for Linux 域
"SSH"    → SSH 远程主机（读取 ~/.ssh/config）
```

- 启动时自动连接常用远程主机
- 单窗口管理本地 + 远程 + WSL

### 🖱️ 鼠标与 GPU

- GPU 加速渲染（高 DPI 无延迟）
- 60fps 滚动和动画
- 选中自动复制到剪贴板（X11）/ 三键粘贴
- 触控板手势：双指缩放、三指滑动 Tab

## 安装

```bash
cd ~/.dotfiles
./wezterm/install.sh
```

安装脚本功能：
1. 安装 WezTerm（brew / apt / choco）
2. 检查 Nerd Font 可用性，无字体时提示用户安装
3. 创建 `wezterm.lua` → `~/.wezterm.lua` 符号链接
4. 设置为默认终端（Linux/macOS）

## 配置验证

```bash
cd ~/.dotfiles
./wezterm/check.sh
```

检查内容：
- Lua 语法：`luac -p wezterm.lua`
- 链接状态：`~/.wezterm.lua` → `wezterm/wezterm.lua`
- 字体安装：Nerd Font 检查
- WezTerm 版本：版本检测与兼容性提示

## 平台差异速查

| 功能 | Linux | macOS | Windows |
|------|-------|-------|---------|
| 集成系统标题栏 | ✅ | ✅ 原生标题栏 | ✅ |
| 透明度支持 | ✅ (Picom) | ✅ | ✅ |
| WSL 域 | ❌ | ❌ | ✅ |
| 触控板手势 | 基础 | 完整支持 | 基础 |
| 输入法 (fcitx) | ✅ | ❌ | ✅ (IME) |
