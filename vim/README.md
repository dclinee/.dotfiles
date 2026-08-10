# Vim 模块

Vim 9+ 兼容的模块化配置，聚焦轻量级体验和多语言开发。

## 目录结构

```
vim/
├── .vimrc                # 主入口（按排序加载子模块）
├── install.sh            # Vim 安装脚本
├── core/                 # 核心配置
│   ├── 00_basic.vim      # 基础选项（缩进、换行、备份）
│   └── 01_keybindings.vim # 快捷键绑定
├── plugins/
│   └── plugins.vim       # 插件定义（vim-plug）
├── ftplugin/             # 文件类型专属配置
│   ├── python.vim        # Python (4 空格缩进)
│   ├── javascript.vim    # JS/TS (2 空格缩进)
│   ├── go.vim            # Go (tabs + 4 空格显示宽)
│   ├── rust.vim          # Rust (4 空格缩进)
│   └── make.vim          # Makefile (tabs)
└── platform/             # 平台特定配置
    ├── linux.vim         # Linux 专属（剪贴板、字体）
    ├── macos.vim         # macOS 专属（剪贴板：macos_clipboard）
    └── windows.vim       # Windows 专属（编码兼容、字体）
```

## Vim 9+ 兼容性

| 问题 | 处理方式 |
|------|----------|
| `\` 行连续语法 | 统一使用单行或替代方式，避免反斜杠 |
| colorscheme 缺失 | 使用 `silent! colorscheme` 不阻塞启动 |
| 插件安装静默 | 输出重定向到 `/dev/null`，超时 30s |
| 文件加载顺序 | 按字母/数字排序，避免依赖问题 |

## 缩进规范

| 文件类型 | 缩进方式 | 缩进宽度 |
|----------|----------|----------|
| Python | 空格 | 4 |
| Rust | 空格 | 4 |
| JavaScript | 空格 | 2 |
| TypeScript | 空格 | 2 |
| Go | Tab | 4 空格显示 |
| Makefile | Tab | 8 空格显示 |
| Shell | 空格 | 4 |
| YAML | 空格 | 2 |
| Markdown | 空格 | 2 |

## 核心特性

### 📦 插件管理（vim-plug）

```vim
call plug#begin('~/.vim/plugged')
" 配色
Plug 'morhetz/gruvbox'
" 注释
Plug 'preservim/nerdcommenter'
" 补全
Plug 'neoclide/coc.nvim', {'branch': 'release'}
" Git 集成
Plug 'tpope/vim-fugitive'
" 文件浏览器
Plug 'preservim/nerdtree'
call plug#end()
```

### ⌨️ 快捷键

| 快捷键 | 功能 |
|--------|------|
| `,` | 前缀键（Leader） |
| `,w` / `,q` | 保存 / 退出 |
| `,n` / `,p` | 下一个 / 上一个 Buffer |
| `,nt` | 切换 NERDTree |
| `,xx` / `,xu` | 注释 / 反注释一行 |
| `,cc` / `,cu` | 注释 / 反注释块 |
| `Ctrl-h/j/k/l` | 移动到左/下/上/右窗口 |
| `%%` | 在命令中展开 `%` 路径 |
| `jj` | 插入模式下快速 Esc |

### 🎨 配色

- 默认配色: `gruvbox` (dark hard contrast)
- 自动降级: 如果配色不存在，自动加载默认配色

### 🔤 搜索优化

- 搜索默认忽略大小写 (`ignorecase smartcase`)
- 输入大写字符时自动改为精确匹配
- 搜索结果高亮，取消搜索后自动清除

## 安装

```bash
cd ~/.dotfiles
./vim/install.sh
# 首次启动 Vim 自动安装插件
vim +PlugInstall +qa
```

安装脚本功能：
1. 检测系统包管理器，安装 Vim / GVim
2. 自动安装 vim-plug 插件管理器（国内镜像回退）
3. 创建 `.vimrc` → `~/.vimrc` 符号链接
4. 启动 Vim 自动执行 `:PlugInstall`

## 性能注意

- 插件懒加载（`Plug 'xxx', { 'on': [...] }` / `{ 'for': [...] }`）
- 避免使用 `autocmd VimEnter *` 阻塞启动
- 启动时间分析：`vim --startuptime vim.log`
