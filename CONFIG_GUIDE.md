# 配置文件指南

## 目录结构

```
.dotfiles/
├── bin/               # 常用脚本
│   └── brew-sync      # Brew 配置同步脚本
├── brew/              # Homebrew 配置
│   ├── Brewfile       # 主 Brewfile 入口
│   ├── Brewfile.common # 通用 Brew 包
│   ├── Brewfile.linux  # Linux 特定 Brew 包
│   ├── Brewfile.macos  # macOS 特定 Brew 包
│   ├── backup_restore.sh # Brew 配置备份与恢复
│   └── install_brew.sh   # Brew 安装脚本
├── python/            # Python 配置
│   ├── __init__.py    # Python 模块初始化
│   ├── pip.conf       # Pip 配置文件
│   ├── pythonrc.py    # Python 交互式增强
│   └── requirements.txt # Python 依赖列表
├── zsh/               # Zsh 配置
│   ├── .zshrc         # 主配置入口
│   ├── core/          # 核心配置模块
│   │   ├── 00_env.zsh     # 环境变量配置
│   │   ├── 01_options.zsh # Zsh 选项配置
│   │   ├── 02_aliases.zsh # 别名配置
│   │   ├── 03_functions.zsh # 自定义函数
│   │   ├── 04_plugins.zsh # 插件配置
│   │   └── 05_starship.zsh # Starship 配置
│   ├── platform/      # 平台特定配置
│   │   ├── darwin.zsh     # macOS 配置
│   │   └── linux.zsh      # Linux 配置
│   ├── plugins/       # 插件目录
│   ├── backup_config.sh # Zsh 配置备份
│   ├── install.sh     # 主安装脚本
│   ├── profile_performance.sh # 性能分析
│   └── starship.toml  # Starship 主题配置
├── .gitignore         # Git 忽略文件
├── CONFIG_GUIDE.md    # 配置文件指南（本文档）
├── CONTRIBUTING.md    # 贡献指南
├── README.md          # 项目说明文档
└── validate.sh        # 配置验证脚本
```

## 配置文件说明

### 1. 根目录文件

- **`.gitignore`** - Git 忽略规则配置，定义了不需要提交到版本控制的文件和目录
- **`CONFIG_GUIDE.md`** - 本指南，提供详细的配置说明
- **`CONTRIBUTING.md`** - 贡献指南，说明如何为项目做贡献
- **`README.md`** - 项目说明文档，包含安装和使用方法
- **`validate.sh`** - 配置验证脚本，用于测试和验证配置的正确性

### 2. bin/ 目录

- **`brew-sync`** - Brew 配置同步脚本，用于更新和同步 Brew 包和配置
  - 使用方法：`./bin/brew-sync`
  - 功能：更新 Brew、升级包、清理旧版本、同步 Brewfile

### 3. brew/ 目录

- **`Brewfile`** - 主 Brewfile 入口，根据不同平台加载对应的 Brewfile
- **`Brewfile.common`** - 通用 Brew 包配置，适用于所有平台
- **`Brewfile.linux`** - Linux 特定 Brew 包配置
- **`Brewfile.macos`** - macOS 特定 Brew 包配置
- **`backup_restore.sh`** - Brew 配置备份与恢复脚本
  - 备份：`./brew/backup_restore.sh backup`
  - 恢复：`./brew/backup_restore.sh restore`
- **`install_brew.sh`** - Brew 安装脚本，用于在不同平台安装 Brew

### 4. python/ 目录

- **`__init__.py`** - Python 模块初始化文件，使 python 目录成为可导入的 Python 模块
- **`pip.conf`** - Pip 配置文件，包含镜像源、缓存目录等配置
- **`pythonrc.py`** - Python 交互式增强配置，提供常用命令和自动补全
- **`requirements.txt`** - Python 依赖列表，包含开发工具和常用库

### 5. zsh/ 目录

- **`.zshrc`** - Zsh 主配置入口，负责加载所有核心配置和插件
- **`core/`** - 核心配置模块，按功能模块化组织
  - **`00_env.zsh`** - 环境变量配置，包括路径、编辑器、语言等
  - **`01_options.zsh`** - Zsh 选项配置，控制 Zsh 的行为
  - **`02_aliases.zsh`** - 别名配置，提供常用命令的快捷方式
  - **`03_functions.zsh`** - 自定义函数，扩展 Zsh 功能
  - **`04_plugins.zsh`** - 插件配置，管理 Zsh 插件
  - **`05_starship.zsh`** - Starship 配置，管理命令提示符样式
- **`platform/`** - 平台特定配置
  - **`darwin.zsh`** - macOS 特定配置
  - **`linux.zsh`** - Linux 特定配置
- **`plugins/`** - 插件目录，用于存放 Zsh 插件
- **`backup_config.sh`** - Zsh 配置备份脚本
- **`install.sh`** - 主安装脚本，用于安装和配置整个 Dotfiles
- **`profile_performance.sh`** - Zsh 性能分析脚本，用于分析启动时间
- **`starship.toml`** - Starship 主题配置文件，定义命令提示符样式

## 安装与更新

### 1. 首次安装

```bash
# 克隆仓库
git clone https://github.com/dclinee/dotfiles.git ~/.dotfiles

# 进入目录
cd ~/.dotfiles

# 运行安装脚本
./zsh/install.sh
```

### 2. 更新配置

```bash
# 更新仓库代码
git pull

# 重新运行安装脚本
./zsh/install.sh
```

### 3. 更新特定模块

```bash
# 更新 Python 依赖
pip3 install --upgrade -r ~/.dotfiles/python/requirements.txt

# 同步 Brew 配置
./bin/brew-sync
```

## 自定义配置

### 1. 本地自定义配置

创建 `~/.zshrc.local` 文件，可以在其中添加本地自定义配置，这些配置不会被 Git 跟踪，适合添加个人隐私信息或特定机器的配置。

### 2. 修改配置文件

- **添加环境变量**：编辑 `zsh/core/00_env.zsh`
- **添加别名**：编辑 `zsh/core/02_aliases.zsh`
- **添加自定义函数**：编辑 `zsh/core/03_functions.zsh`
- **修改主题样式**：编辑 `zsh/starship.toml`
- **添加 Python 依赖**：编辑 `python/requirements.txt`
- **添加 Brew 包**：编辑对应的 `Brewfile.*` 文件

### 3. 最佳实践

- **保持模块化**：将不同功能的配置放在不同的文件中
- **使用注释**：为复杂配置添加注释，便于后续维护
- **测试变更**：在修改配置后，使用 `validate.sh` 脚本验证配置的正确性
- **备份配置**：定期使用 `backup_config.sh` 和 `backup_restore.sh` 备份配置

## 故障排除

### 1. 常见问题

- **zinit 插件加载失败**：检查 `ZINIT_DIR` 路径是否正确，确保 `zinit.zsh` 文件存在
- **Python 依赖安装失败**：检查 Python 版本是否兼容，尝试更新 pip 后重试
- **Brew 安装包失败**：检查网络连接，尝试更换镜像源
- **Zsh 启动缓慢**：使用 `profile_performance.sh` 分析启动时间，找出瓶颈

### 2. 调试方法

- **启用 Zsh 调试模式**：`zsh -x ~/.zshrc`
- **检查配置语法**：`zsh -n ~/.zshrc`
- **查看日志文件**：`tail -f ~/.dotfiles/brew-sync.log`
- **使用 validate.sh 验证**：`./validate.sh --dry-run`

## 性能优化

1. **减少插件数量**：只加载必要的插件
2. **优化 zinit 配置**：使用 `zinit light` 代替 `zinit load` 加载插件
3. **使用异步加载**：对于耗时的插件，使用 `zinit wait` 异步加载
4. **优化 Starship 配置**：减少不必要的模块，使用缓存
5. **定期清理**：使用 `brew cleanup` 和 `zsh -c "zinit cleanup"` 清理旧文件

## 跨平台兼容

本配置支持 Linux 和 macOS 平台，通过以下方式实现跨平台兼容：

- **条件加载**：在 `.zshrc` 和 `core/00_env.zsh` 中根据 `OSTYPE` 条件加载不同配置
- **独立配置文件**：`platform/` 目录下包含不同平台的特定配置
- **Brew 平台分离**：使用不同的 `Brewfile.*` 文件管理不同平台的 Brew 包
- **路径自动检测**：自动检测 Homebrew 和其他工具的安装路径

## 配置备份与恢复

### 1. Zsh 配置备份

```bash
./zsh/backup_config.sh
```

### 2. Brew 配置备份与恢复

```bash
# 备份
./brew/backup_restore.sh backup

# 恢复
./brew/backup_restore.sh restore
```

### 3. 手动备份

```bash
# 备份整个 dotfiles 目录
tar -czf dotfiles-backup.tar.gz ~/.dotfiles

# 恢复
mkdir -p ~/.dotfiles
.tar -xzf dotfiles-backup.tar.gz -C ~/.dotfiles
```

## 贡献指南

请参考 `CONTRIBUTING.md` 文件，了解如何为项目做贡献。
