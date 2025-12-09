# Vim 配置

这是一个现代化的 Vim 配置，专注于提供高效、美观且易于维护的开发环境。

## ✨ 功能特性

### 🎯 核心功能
- **现代化 Vim 配置**：基于 Vim 8.0+，提供高效的开发体验
- **插件管理**：使用 Vim-plug 作为插件管理器，支持并行加载和异步安装
- **美观主题**：集成多种现代化主题（Gruvbox、Solarized、Molokai、Dracula）
- **跨平台支持**：完美兼容 Linux、macOS 和 Windows
- **自动配置**：一键安装脚本，自动处理依赖和配置
- **模块化设计**：核心配置、插件、主题分离，易于维护和扩展

### 📦 内置插件

#### 主题插件
- `morhetz/gruvbox` - Gruvbox 主题
- `solarized/vim` - Solarized 主题
- `tomasr/molokai` - Molokai 主题
- `dracula/vim` - Dracula 主题

#### 语法高亮插件
- `sheerun/vim-polyglot` - 多语言语法高亮
- `nvim-treesitter/nvim-treesitter` - 高级语法解析

#### 自动补全插件
- `neoclide/coc.nvim` - 智能补全
- `hrsh7th/nvim-compe` - 补全引擎
- `hrsh7th/vim-vsnip` - 代码片段

#### 文件搜索插件
- `junegunn/fzf` - 文件搜索
- `junegunn/fzf.vim` - FZF Vim 集成
- `nvim-telescope/telescope.nvim` - 现代化搜索

#### 代码导航插件
- `preservim/tagbar` - 标签导航
- `majutsushi/tagbar` - 标签导航
- `vim-scripts/taglist.vim` - 标签列表

#### Git 集成插件
- `tpope/vim-fugitive` - Git 集成
- `airblade/vim-gitgutter` - Git 状态显示
- `lewis6991/gitsigns.nvim` - Git 状态显示

#### 其他实用插件
- `preservim/nerdcommenter` - 代码注释
- `scrooloose/nerdtree` - 文件浏览器
- `ryanoasis/vim-devicons` - 图标支持
- `vim-airline/vim-airline` - 状态栏增强
- `terryma/vim-multiple-cursors` - 多光标编辑
- `mbbill/undotree` - 撤销树
- `jiangmiao/auto-pairs` - 自动括号匹配
- `tpope/vim-surround` - 环绕字符操作
- `easymotion/vim-easymotion` - 快速移动

#### 语言特定插件
- `davidhalter/jedi-vim` - Python 补全
- `rust-lang/rust.vim` - Rust 支持
- `pangloss/vim-javascript` - JavaScript 支持
- `maxmellon/vim-jsx-pretty` - JSX 支持
- `hashivim/vim-terraform` - Terraform 支持
- `fatih/vim-go` - Go 支持

## 🚀 安装

### 前置要求
- **Vim** - 8.0+ 版本
- **Git** - 用于克隆仓库
- **curl** - 用于下载安装脚本

### 快速安装

```bash
# 克隆仓库
git clone https://github.com/dclinee/dotfiles.git ~/.dotfiles

# 进入目录
cd ~/.dotfiles

# 创建符号链接
ln -sf ~/.dotfiles/vim/.vimrc ~/.vimrc

# 运行 Vim，自动安装插件
vim

# 或手动安装插件
vim +PlugInstall +qall
```

## 📁 配置结构

```
~/.dotfiles/vim/
├── core/                # 核心配置
│   ├── 00_basic.vim     # 基础配置
│   └── 01_keybindings.vim # 快捷键映射
├── plugins/             # 插件配置
│   └── plugins.vim      # 插件管理配置
├── platform/            # 平台特定配置
│   ├── linux.vim        # Linux 配置
│   ├── macos.vim        # macOS 配置
│   └── windows.vim      # Windows 配置
├── .vimrc               # 主配置入口
└── README.md            # Vim 配置文档
```

## 🎨 主题配置

### 使用内置主题

在 `~/.dotfiles/vim/core/00_basic.vim` 中修改：

```vim
" 配色方案
set background=dark
colorscheme gruvbox  " 使用 Gruvbox 主题
" colorscheme solarized  " 使用 Solarized 主题
" colorscheme molokai   " 使用 Molokai 主题
" colorscheme dracula   " 使用 Dracula 主题
```

## ⌨️ 快捷键配置

### 基础快捷键
| 快捷键 | 功能 |
|--------|------|
| `<Leader>w` | 保存 |
| `<Leader>q` | 退出 |
| `<Leader>wq` | 保存退出 |
| `<Leader>qa` | 退出所有 |
| `<Leader>q!` | 强制退出 |

### 窗口管理
| 快捷键 | 功能 |
|--------|------|
| `<Leader>sv` | 垂直分割 |
| `<Leader>sh` | 水平分割 |
| `<Leader>sc` | 关闭窗口 |
| `<Leader>so` | 关闭其他窗口 |
| `<C-h>` | 向左切换窗口 |
| `<C-j>` | 向下切换窗口 |
| `<C-k>` | 向上切换窗口 |
| `<C-l>` | 向右切换窗口 |

### 标签页管理
| 快捷键 | 功能 |
|--------|------|
| `<Leader>tn` | 新建标签页 |
| `<Leader>tc` | 关闭标签页 |
| `<Leader>to` | 关闭其他标签页 |
| `<Leader>tl` | 下一个标签页 |
| `<Leader>th` | 上一个标签页 |
| `<S-l>` | 下一个标签页 |
| `<S-h>` | 上一个标签页 |

### 其他快捷键
| 快捷键 | 功能 |
|--------|------|
| `<Leader>n` | 打开/关闭 Nerdtree |
| `<Leader>t` | 打开/关闭 Tagbar |
| `<Leader>u` | 打开/关闭 Undotree |
| `<Leader>/` | 清除搜索高亮 |
| `<Leader>y` | 复制到系统剪贴板 |
| `<Leader>p` | 从系统剪贴板粘贴 |
| `<Leader>r` | 全局替换 |
| `<Leader>=` | 格式化代码 |
| `<Leader>c` | 注释/取消注释 |

## 🎛️ 自定义配置

### 添加自定义配置

创建 `~/.vimrc.local` 文件，添加你的自定义配置：

```vim
" 示例：添加自定义快捷键
nnoremap <Leader>ff :Telescope find_files<CR>

" 示例：修改主题
set background=light
colorscheme solarized

" 示例：添加自定义插件
" Plug 'username/plugin-name'
```

## 🔄 更新与维护

### 更新配置

```bash
# 拉取最新配置
git pull

# 重新加载配置
vim +source ~/.vimrc +qall
```

### 更新插件

```bash
# 更新所有插件
vim +PlugUpdate +qall

# 更新特定插件
vim +PlugUpdate plugin-name +qall
```

## 🐛 故障排除

### 常见问题

1. **插件无法加载**
   - 检查 `~/.vim/plugged` 目录是否存在
   - 重新运行 `vim +PlugInstall +qall`

2. **主题不显示**
   - 检查主题插件是否已安装
   - 确保 `syntax enable` 已启用

3. **图标不显示**
   - 确保已安装支持图标的终端字体
   - 推荐使用 Nerd Fonts

### 调试模式

```bash
# 启用详细输出
vim -V

# 查看插件加载情况
vim --startuptime startuptime.log +qall
cat startuptime.log
```

## 📝 许可证

MIT License

## 🤝 贡献

欢迎提交 Issue 和 Pull Request 来改进这个项目！
