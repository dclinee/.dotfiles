# dclinee 的 Dotfiles

这是一个现代化的 Dotfiles 配置，专注于提供高效、美观且易于维护的 Zsh 开发环境。
**开箱即用**，让大多数开发者在新机器上几分钟内即可获得完整的开发环境，无需花费大量时间配置。

## ✨ 功能特性

### 🎯 核心功能
- **一键安装**：`bootstrap.sh` 或 `make install` 自动完成全部配置
- **现代化 Zsh 配置**：基于 Zsh 5.9+，提供高效的命令行体验
- **插件管理**：使用 Zinit 作为插件管理器，支持并行加载和异步安装
- **美观主题**：集成 Starship 主题，提供现代化的提示符设计
- **Wezterm 终端支持**：跨平台终端配置，提供现代化的终端体验
- **Vim 配置**：内置 vim-plug 与常用插件，开箱即用
- **Tmux 配置**：内置 TPM 插件管理与 Vim 风格快捷键
- **Git 全局配置**：常用别名、颜色、pager 模板，支持 `~/.gitconfig.local` 覆盖
- **EditorConfig**：跨编辑器统一缩进、换行、编码规则
- **跨平台支持**：完美兼容 Linux (Ubuntu/Debian) 和 macOS
- **模块化设计**：核心配置、插件、主题分离，易于维护和扩展
- **统一命令入口**：Makefile 暴露 install/update/backup/test/check 等命令

### 📦 内置插件
- `zsh-users/zsh-autosuggestions` - 智能命令补全
- `zsh-users/zsh-syntax-highlighting` - 语法高亮
- `wfxr/forgit` - Git 快捷操作
- `zsh-users/zsh-history-substring-search` - 历史命令搜索
- `agkozak/zsh-z` - 智能目录跳转
- `ajeetdsouza/zoxide` - 快速目录导航
- `Aloxaf/fzf-tab` - 模糊查找补全

### 🎨 主题与外观
- **Starship** - 现代化、高度可定制的提示符
- **响应式设计** - 根据屏幕宽度自动调整
- **丰富的状态信息** - 显示 Git 状态、命令执行时间、Python 虚拟环境等
- **Nerd Font 自动降级** - 未安装 Nerd Font 时自动切换到无图标配置

## 🚀 安装

### 前置要求
- **Git** - 用于克隆仓库
- **Zsh** - 5.9+ 版本
- **curl** - 用于下载安装脚本

### 方式一：一键安装（推荐新机器使用）

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
```

### 方式二：使用 Makefile

```bash
cd ~/.dotfiles
make install    # 一键安装所有配置
make zsh        # 仅安装 Zsh
make vim        # 仅安装 Vim
make tmux       # 仅安装 Tmux
make git        # 仅安装 Git 配置
make brew       # 执行 brew bundle
make help       # 查看所有可用命令
```

### 方式三：单独运行各模块安装脚本

```bash
./zsh/install.sh        # Zsh + Homebrew + zinit + starship + zoxide
./vim/install.sh        # Vim + vim-plug
./wezterm/install.sh    # WezTerm 配置
```

### 使用国内镜像加速

```bash
# 使用清华镜像源
export USE_MIRROR=tsinghua
./zsh/install.sh
```

## 📁 配置结构

```
~/.dotfiles/
├── bootstrap.sh          # 一键安装入口（新机器推荐）
├── Makefile              # 统一命令入口（install/update/backup/test/check）
├── .editorconfig         # 跨编辑器代码风格统一配置
├── zsh/                  # Zsh 配置
│   ├── .zshrc            # 主配置入口
│   ├── .zshenv           # 最早加载的环境变量（PATH/Homebrew）
│   ├── core/             # 核心配置模块
│   │   ├── 00_env.zsh     # 环境变量配置
│   │   ├── 01_options.zsh # Zsh 选项配置
│   │   ├── 02_aliases.zsh # 别名配置
│   │   ├── 03_functions.zsh # 自定义函数（含 check_env 诊断）
│   │   ├── 04_plugins.zsh # 插件配置（zinit）
│   │   └── 05_starship.zsh # Starship 主题配置
│   ├── lib/              # 公共库
│   │   └── output.sh      # 统一输出函数（echo_step/echo_success...）
│   ├── platform/         # 平台特定配置
│   │   ├── linux.zsh      # Linux 配置
│   │   └── macos.zsh      # macOS 配置
│   ├── plugins/          # 插件目录
│   │   ├── zinit/        # Zinit 插件管理器
│   │   └── zoxide/       # Zoxide 插件
│   ├── install.sh        # Zsh 安装脚本（集成 brew bundle）
│   ├── profile_performance.sh # 启动性能分析
│   └── starship.toml     # Starship 主题配置
├── vim/                  # Vim 配置
│   ├── core/             # 核心配置
│   │   ├── 00_basic.vim     # 基础配置
│   │   └── 01_keybindings.vim # 快捷键映射
│   ├── plugins/          # 插件配置
│   │   └── plugins.vim      # 插件管理配置
│   ├── platform/         # 平台特定配置
│   │   ├── linux.vim        # Linux 配置
│   │   └── macos.vim        # macOS 配置
│   ├── .vimrc            # 主配置入口
│   ├── install.sh        # Vim 安装脚本
│   └── README.md         # Vim 配置文档
├── tmux/                 # Tmux 配置
│   └── .tmux.conf        # Tmux 主配置（TPM + Vim 风格快捷键）
├── git/                  # Git 全局配置
│   ├── .gitconfig        # Git 配置模板（别名/颜色/pager）
│   └── .gitignore_global # 全局忽略规则
├── brew/                 # Homebrew 配置
│   ├── Brewfile          # 主 Brewfile（按平台分发）
│   ├── Brewfile.common   # 通用包（git/gh/fzf/ripgrep/bat/eza...）
│   ├── Brewfile.linux    # Linux 特定包
│   ├── Brewfile.macos    # macOS 特定包
│   └── install_brew.sh   # Brew 安装脚本
├── python/               # Python 配置
│   ├── __init__.py       # Python 模块入口
│   ├── pythonrc.py       # Python 交互式配置
│   ├── pip.conf          # Pip 配置
│   ├── requirements.txt  # Python 依赖
│   ├── pyproject.toml    # 现代打包配置（符合PEP 517/518标准）
│   └── setup_env.py      # 环境设置脚本
├── wezterm/              # WezTerm 终端配置
├── bin/                  # 自定义脚本
│   └── brew-sync         # Brew 同步脚本
├── test_install.sh       # 静态与动态测试脚本
├── validate.sh           # 配置验证脚本
└── README.md             # 项目文档
```

## ⚙️ 核心功能详解

### 🔧 插件管理

我们的插件管理系统具有以下特点：
- **智能加载**：自动跟踪已加载插件，防止重复加载
- **错误处理**：完善的错误处理机制，提供清晰的警告信息
- **版本锁定**：支持通过 .lock 文件锁定插件版本
- **灵活配置**：支持多种插件来源和初始化文件格式
- **高效加载**：优化的加载逻辑，提高启动速度

### 🐍 Python 配置

- **现代打包**：符合 PEP 517/518 标准的 pyproject.toml 配置
- **简化的 setup.py**：主配置已迁移到 pyproject.toml
- **自动激活**：检测当前目录的 .venv 目录并自动激活虚拟环境
- **优化路径**：自动配置 Python 路径和环境变量
- **完整的 pyenv 支持**：包括版本管理和虚拟环境集成
- **增强的交互式体验**：丰富的内置函数和自动导入
- **统一的 pip 配置**：使用国内镜像源加速下载

### 📁 现代化配置结构

- **模块化设计**：核心配置、插件、主题分离，易于维护和扩展
- **清晰的层级**：按功能和平台组织配置文件
- **自动化验证**：内置 validate.sh 脚本，验证所有配置文件的语法
- **跨平台兼容**：完美支持 Linux 和 macOS

### 📚 历史命令增强

- **增强的历史记录**：保存 100,000+ 条命令
- **时间戳**：每条命令显示执行时间
- **忽略无用命令**：自动过滤 `ls`、`cd` 等频繁使用但价值低的命令
- **智能搜索**：使用 `Ctrl+R` 或箭头键搜索历史命令

### 🌐 网络工具

- **Brew 配置**：预配置了常用的开发工具
- **镜像支持**：自动使用国内镜像加速下载
- **平台适配**：根据不同平台自动选择合适的包

## 🎛️ 自定义配置

### 添加自定义 Zsh 配置

创建 `~/.zshrc.local` 文件，添加你的自定义配置：

```zsh
# 示例：添加自定义别名
alias ll='ls -la'

# 示例：添加自定义函数
function myfunc() {
    echo "Hello from custom function!"
}
```

### 自定义 Starship 主题

编辑 `~/.dotfiles/zsh/starship.toml` 文件，根据 [Starship 文档](https://starship.rs/config/) 自定义主题。

## 🔄 更新与维护

### 使用 Makefile 维护（推荐）

```bash
cd ~/.dotfiles

make update     # 一键更新：git pull + zinit update + brew upgrade
make backup     # 备份当前配置
make check      # 环境检查（调用 check_env）
make test       # 运行静态测试
make perf       # Zsh 启动性能分析
make validate   # 验证所有配置文件语法
make clean      # 清理缓存（zcompdump / brew / zinit）
make help       # 查看所有可用命令
```

### 手动更新配置

```bash
# 进入 dotfiles 目录
cd ~/.dotfiles

# 拉取最新配置
git pull

# 重新运行安装脚本以应用更新
./zsh/install.sh
```

### 更新插件

```bash
# 更新所有 zinit 插件
zinit update --all

# 更新特定插件
zinit update zsh-users/zsh-autosuggestions
```

## 🐛 故障排除

### 常见问题

1. **Zinit 插件无法加载**
   - 检查 `~/.dotfiles/zsh/plugins/zinit` 目录是否存在
   - 重新运行安装脚本：`./zsh/install.sh`

2. **Starship 主题不显示**
   - 检查 `starship` 命令是否安装：`command -v starship`
   - 重新安装 starship：`curl -sS https://starship.rs/install.sh | sh -s -- -y`

3. **安装脚本失败**
   - 检查是否有 sudo 权限
   - 检查网络连接
   - 查看 `debug.log` 文件获取详细错误信息

### 调试模式

```bash
# 启用详细输出
zsh -x -c 'source ~/.zshrc'

# 查看配置加载过程
ZSH_DEBUG=1 zsh
```

## 📝 许可证

MIT License

## 🤝 贡献

欢迎提交 Issue 和 Pull Request 来改进这个项目！

## 📞 联系方式

- GitHub: [@dclinee](https://github.com/dclinee)
- Email: dengchanglin8@outlook.com

---

**享受高效的命令行体验！** 🎉