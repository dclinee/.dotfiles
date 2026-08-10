# Vim 模块

现代化 Vim 配置，基于 vim-plug 插件管理器，集成 coc.nvim 作为 LSP 后端，LazyVim 风格主题。

## 文件结构

```
vim/
├── .vimrc                         # 主配置入口
├── install.sh                     # Vim 安装脚本
├── vimrc.local.example            # 本地自定义配置模板
├── core/                          # 核心配置
│   ├── 00_basic.vim               # 基础设置（编码、缩进、光标）
│   └── 01_keybindings.vim         # 快捷键映射
├── plugins/                       # 插件配置
│   └── plugins.vim                # vim-plug 插件列表与配置
├── platform/                      # 平台特定配置
│   ├── linux.vim                  # Linux 配置
│   ├── macos.vim                  # macOS 配置
│   └── windows.vim                # Windows 配置
├── ftplugin/                      # 文件类型配置
│   ├── python.vim                 # Python 缩进（4 空格）
│   ├── javascript.vim            # JavaScript 缩进（2 空格）
│   ├── go.vim                     # Go 缩进（tabs）
│   ├── make.vim                   # Makefile 缩进（tabs）
│   └── rust.vim                   # Rust 缩进（4 空格）
└── .gitignore
```

## 快速使用

### 安装

```bash
# 通过 Makefile
make vim

# 直接执行
./vim/install.sh

# 通过 bootstrap.sh
./bootstrap.sh --vim
```

### 插件列表

| 插件 | 说明 |
|------|------|
| `morhetz/gruvbox` | Gruvbox 主题（基础可用） |
| `ghifarit53/tokyonight-vim` | Tokyo Night 主题（LazyVim 风格） |
| `neoclide/coc.nvim` | 智能补全 + LSP 统一后端 |
| `preservim/nerdtree` | 文件浏览器 |
| `preservim/tagbar` | 标签导航 |
| `tpope/vim-fugitive` | Git 集成 |
| `airblade/vim-gitgutter` | Git 状态标记 |
| `preservim/nerdcommenter` | 代码注释 |
| `ryanoasis/vim-devicons` | 文件图标支持 |
| `vim-airline/vim-airline` | 状态栏增强 |
| `terryma/vim-multiple-cursors` | 多光标编辑 |
| `mbbill/undotree` | 撤销树 |
| `jiangmiao/auto-pairs` | 自动括号匹配 |
| `tpope/vim-surround` | 环绕字符操作 |
| `junegunn/fzf.vim` | FZF 文件搜索 |

### Coc 扩展

首次启动时自动安装以下 coc 扩展：
`coc-json`, `coc-pyright`, `coc-java`, `coc-html`, `coc-css`, `coc-tsserver`, `coc-vimlsp`, `coc-go`, `coc-rust-analyzer`, `coc-snippets`, `coc-markdownlint`, `coc-prettier`, `coc-yaml`, `coc-toml`, `coc-sh`, `coc-docker`, `coc-terraform`, `coc-lua`, `coc-spell-checker`

## 常用快捷键

| 快捷键 | 功能 |
|--------|------|
| `<Leader>n` | 切换 Nerdtree |
| `<Leader>t` | 切换 Tagbar |
| `<Leader>ff` | FZF 文件搜索 |
| `<Leader>fg` | FZF Git 文件搜索 |
| `<Leader>fs` | FZF 文本搜索 |
| `<Leader>gs` | Fugitive Git 面板 |
| `<Leader>gb` | Fugitive blame |
| `<Leader>gl` | Fugitive log |
| `<Leader>u` | Undotree 切换 |

## 自定义配置

复制 `vimrc.local.example` 到 `~/.vimrc.local`：

```vim
" ~/.vimrc.local 示例
let g:your_var = 'value'
```

## 注意事项

- Vim 9.2+ 不支持 `\` 行续语法，所有插件配置已改为单行
- coc.nvim 首次安装扩展需要网络连接
- vim-plug 安装失败时脚本会静默跳过，不阻塞启动
