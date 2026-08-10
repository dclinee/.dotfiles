# Zsh 模块

现代化 Zsh 配置，基于 Zsh 5.9+，使用 Zinit 插件管理器，集成 Starship 提示符。

## 文件结构

```
zsh/
├── .zshrc                        # 主配置入口
├── .zshenv                       # 最早加载的环境变量（PATH/Homebrew）
├── install.sh                    # Zsh 安装脚本（Homebrew + zinit + starship + zoxide）
├── profile_performance.sh        # 启动性能分析工具
├── starship.toml                 # Starship 主题配置（Nerd Font 版本）
├── starship_fallback.toml        # Starship 回退配置（无 Nerd Font 版本）
├── core/                         # 核心配置模块
│   ├── 00_env.zsh                # 环境变量（PATH、语言、历史）
│   ├── 01_options.zsh            # Zsh 选项（目录栈、自动补全、语法）
│   ├── 02_aliases.zsh            # 别名定义（ls、git、安全等）
│   ├── 03_functions.zsh          # 自定义函数（check_env、mkcd、extract 等）
│   ├── 04_plugins.zsh            # zinit 插件加载配置
│   └── 05_starship.zsh           # Starship 主题加载逻辑
├── functions/                    # 功能专题（从 03_functions.zsh 拆分）
│   ├── nav.zsh                   # 导航函数（z、j、bk）
│   ├── file.zsh                  # 文件操作（mkcd、extract、tre）
│   ├── net.zsh                   # 网络工具（serve、public_ip）
│   ├── git.zsh                   # Git 增强（gcb、gsw、gignore）
│   ├── dev.zsh                   # 开发辅助（pyvirt、portkill）
│   └── diagnostic.zsh            # 环境诊断（check_env、check_dependencies）
├── platform/                     # 平台特定配置
│   ├── linux.zsh                 # Linux 配置
│   └── macos.zsh                 # macOS 配置
├── lib/                          # 公共库（已迁移到项目根 lib/）
└── .gitignore
```

## 快速使用

### 安装

```bash
# 通过 Makefile
make zsh

# 直接执行
./zsh/install.sh

# 通过 bootstrap.sh
./bootstrap.sh --zsh
```

### 日常维护

```bash
# 环境诊断
check_env
check_dependencies

# 插件管理
list_plugins          # 列出已加载插件
update_plugins        # 更新所有插件

# 性能分析
ZSH_DEBUG_PLUGINS=1 zsh   # 显示插件加载耗时
./zsh/profile_performance.sh  # 启动性能测试
```

## 配置加载顺序

```
.zshenv          ← 所有 shell 会话最先加载（PATH、Homebrew）
  ↓
.zshrc           ← 交互式 shell 加载
  ↓
core/00_env.zsh     ← 环境变量
core/01_options.zsh ← Zsh 选项
core/02_aliases.zsh ← 别名定义
core/03_functions.zsh ← 加载 functions/ 专题文件
core/04_plugins.zsh ← zinit 插件加载
core/05_starship.zsh ← Starship 提示符
  ↓
platform/linux.zsh  ← 平台特定配置
  或
platform/macos.zsh
  ↓
~/.zshrc.local      ← 本地自定义配置（不纳入仓库）
```

## 插件列表

| 插件 | 说明 | 加载方式 |
|------|------|---------|
| `zsh-users/zsh-autosuggestions` | 历史命令补全建议 | 同步 |
| `wfxr/forgit` | Git 交互式增强（g、ga、gd） | 同步 |
| `zsh-users/zsh-history-substring-search` | 历史命令子串搜索 | 同步 |
| `agkozak/zsh-z` | 智能目录跳转 | 同步 |
| `Aloxaf/fzf-tab` | Tab 补全模糊查找 | 懒加载 |
| `zsh-users/zsh-syntax-highlighting` | 命令行语法高亮 | 懒加载 |

## 自定义配置

在 `~/.zshrc.local` 中添加个人配置（不会被 git 跟踪）：

```zsh
# 个人别名
alias myproject='cd ~/projects/my-project'

# 环境变量
export MY_API_KEY="your-key-here"
```

## 字体

推荐安装 Nerd Font 以获得最佳 Starship 图标体验：

```bash
# macOS
brew install --cask font-fira-code-nerd-font

# Linux
mkdir -p ~/.local/share/fonts && cd ~/.local/share/fonts
curl -fLO https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/FiraCode.zip
unzip FiraCode.zip && rm FiraCode.zip && fc-cache -fv
```

未安装 Nerd Font 时，Starship 会自动降级到无图标配置。
