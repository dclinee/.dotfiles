" ===================================
" 基础配置
" ===================================

" 设置Vim版本要求（Vim 8+ 默认 nocompatible，无需手动设置）
if v:version < 800
  echohl WarningMsg
  echo "警告: Vim版本过低，部分功能可能无法使用"
  echohl None
endif

" 文件编码
set encoding=utf-8
set fileencoding=utf-8
set fileencodings=utf-8,gbk,gb2312,cp936

" 自动检测文件类型
filetype plugin indent on

" 显示行号
set number

" 显示相对行号
set relativenumber

" 显示光标所在位置
set ruler

" 显示状态栏
set laststatus=2

" 显示命令行
set showcmd

" 启用鼠标
set mouse=a

" 启用语法高亮
syntax enable

" 自动缩进
set autoindent
set smartindent
set cindent

" 缩进设置（默认 4 空格，特定文件类型在 ftplugin/ 中覆盖）
set tabstop=4
set softtabstop=4
set shiftwidth=4
set expandtab
set smarttab

" 搜索设置
set ignorecase
set smartcase
set hlsearch
set incsearch
set nofoldenable

" 滚动设置
set scrolloff=8
set sidescrolloff=8

" 显示不可见字符
set list
set listchars=tab:→\ ,trail:·,nbsp:␣

" 自动换行
set wrap
set linebreak
set textwidth=80

" 启用自动保存
set autowrite
set autowriteall

" 启用自动恢复
set undofile
set undodir=~/.cache/vim/undo
set backupdir=~/.cache/vim/backup
set directory=~/.cache/vim/swap

" 确保缓存目录存在
silent! call mkdir(expand('~/.cache/vim/undo'), 'p')
silent! call mkdir(expand('~/.cache/vim/backup'), 'p')
silent! call mkdir(expand('~/.cache/vim/swap'), 'p')

" 拼写检查（默认关闭，按需开启）
" set spell
" set spelllang=en_us,zh_cn

" 状态栏显示编码和文件类型（当安装了 vim-airline 时，Airline 会完整覆盖 statusline；此处作为插件未就绪时的兜底）
set statusline+=%F\ %m\ %r\ %y\ %{&fileencoding?&fileencoding:&encoding}\ %=\ %l,%c%V\ %P

" ===================================
" 配色方案（Tokyo Night 风格，模仿 LazyVim）
" ===================================
set background=dark

" 优先使用 termguicolors（真彩色），需要 +termguicolors 编译支持
" 注意：platform/macos.vim / platform/linux.vim 会根据终端类型再补强；
"       Lua options.lua（Neovim 叠加层启用时）也会重复设置一次，均为幂等操作
if has('termguicolors')
  set termguicolors
endif

" 加载配色方案
" 优先尝试 tokyonight-vim，失败则回退到 gruvbox
if filereadable(expand('~/.vim/plugged/tokyonight-vim/colors/tokyonight.vim'))
  silent! colorscheme tokyonight
  let g:colors_name = 'tokyonight'
elseif filereadable(expand('~/.vim/plugged/gruvbox/colors/gruvbox.vim'))
  silent! colorscheme gruvbox
  let g:colors_name = 'gruvbox'
else
  " 无主题可用，使用空配色方案
  silent! colorscheme default
  let g:colors_name = 'default'
endif

" ===================================
" Tokyo Night 风格高亮（模拟 LazyVim 视觉效果）
" 这些高亮覆盖主题默认值，实现 LazyVim 风格的视觉
" 即使主题加载失败，这些设置仍然会生效
" ===================================

" 先清除所有高亮，重新设置
if exists('*synhi_GroupID')
  " Vim 9: 使用更简单的方式清除
endif

" 透明背景（LazyVim 风格 - 让终端背景色透出）
" 注意：需要终端本身支持透明背景
if has('termguicolors')
  " 背景透明化
  highlight Normal ctermbg=NONE guibg=NONE
  highlight NormalNC ctermbg=NONE guibg=NONE
  highlight EndOfBuffer ctermbg=NONE guibg=NONE
  highlight SignColumn ctermbg=NONE guibg=NONE
  highlight FoldColumn ctermbg=NONE guibg=NONE
  highlight LineNr ctermbg=NONE guibg=NONE
  highlight CursorLineNr ctermbg=NONE guibg=NONE
  highlight VertSplit ctermbg=NONE guibg=NONE
  highlight StatusLine ctermbg=NONE guibg=NONE
  highlight StatusLineNC ctermbg=NONE guibg=NONE
  highlight TabLine ctermbg=NONE guibg=NONE
  highlight TabLineFill ctermbg=NONE guibg=NONE
  highlight TabLineSel ctermbg=NONE guibg=NONE
  highlight WinSeparator ctermbg=NONE guibg=NONE
  highlight NormalFloat ctermbg=NONE guibg=NONE
  highlight FloatBorder ctermbg=NONE guifg=#3b4261
  highlight Pmenu ctermbg=NONE guibg=NONE
  highlight PmenuSbar ctermbg=NONE guibg=NONE
  highlight PmenuThumb ctermbg=NONE guibg=NONE
  highlight PmenuSel ctermfg=black guifg=#7dcfff
endif

" 斜体注释和关键字（LazyVim 风格 - 代码高亮斜体）
highlight Comment cterm=italic gui=italic
highlight SpecialComment cterm=italic gui=italic
highlight NonText cterm=italic gui=italic
highlight Function cterm=italic gui=italic
highlight Keyword cterm=italic gui=italic
highlight Repeat cterm=italic gui=italic
highlight Statement cterm=italic gui=italic
highlight Conditional cterm=italic gui=italic
highlight PreProc cterm=italic gui=italic
highlight StorageClass cterm=italic gui=italic
highlight Type cterm=italic gui=italic
highlight Structure cterm=italic gui=italic
highlight Typedef cterm=italic gui=italic
highlight Exception cterm=italic gui=italic
highlight Define cterm=italic gui=italic
highlight Macro cterm=italic gui=italic
highlight Special cterm=italic gui=italic

" 行号低对比度（LazyVim 风格 - 行号不抢眼）
highlight LineNr ctermfg=240 guifg=#3b4261
highlight CursorLineNr ctermfg=242 guifg=#706d61

" 光标行高亮（LazyVim 风格 - 柔和高亮）
highlight CursorLine cterm=NONE ctermbg=235 guibg=#1a1b26
highlight CursorColumn cterm=NONE ctermbg=235 guibg=#1a1b26

" 视觉选择背景（Tokyo Night storm 风格）
highlight Visual ctermbg=24 guibg=#283457

" 搜索/替换高亮（LazyVim 风格）
highlight Search cterm=bold ctermbg=yellow ctermfg=black guibg=#3d59a1 guifg=#e0af68
highlight IncSearch cterm=bold ctermbg=yellow ctermfg=black guibg=#ff9e64 guifg=#1a1b26

" 诊断高亮（LazyVim 风格 - 清晰的错误/警告颜色）
highlight Error ctermfg=196 guifg=#f7768e
highlight Warning ctermfg=214 guifg=#e0af68
highlight Info ctermfg=39 guifg=#7dcfff
highlight Hint ctermfg=220 guifg=#e0af68

" 分隔符高亮（LazyVim 风格 - 细微分隔）
highlight WinSeparator ctermfg=240 guifg=#3b4261
highlight VertSplit ctermfg=240 guifg=#3b4261

" Git diff 高亮（Tokyo Night 风格）
highlight DiffAdd ctermbg=22 guibg=#283457
highlight DiffDelete ctermbg=52 guibg=#3d1f25
highlight DiffChange ctermbg=17 guibg=#1f2335
highlight DiffText ctermbg=23 guibg=#2b334a

" Fzf 透明（LazyVim 风格）
highlight FzfNormal ctermbg=NONE guibg=NONE
highlight FzfBorder ctermfg=240 guifg=#3b4261

" Coc 浮窗透明（LazyVim 风格）
highlight CocNormal ctermbg=NONE guibg=NONE
highlight CocBorder ctermfg=240 guifg=#3b4261
highlight CocMenuSel ctermfg=black guifg=#7dcfff

" GitGutter 标记颜色（Tokyo Night 风格）
highlight GitGutterAdd ctermfg=42 guifg=#9ece6a
highlight GitGutterChange ctermfg=214 guifg=#e0af68
highlight GitGutterDelete ctermfg=203 guifg=#f7768e

" ===================================
" Tokyo Night 完整颜色方案（不依赖外部主题）
" 这些颜色覆盖所有常用高亮组，确保 LazyVim 风格的视觉
" ===================================
" 语法高亮颜色
highlight String ctermfg=221 guifg=#9ece6a
highlight Character ctermfg=221 guifg=#9ece6a
highlight Number ctermfg=214 guifg=#ff9e64
highlight Boolean ctermfg=220 guifg=#e0af68
highlight Float ctermfg=214 guifg=#ff9e64
highlight Constant ctermfg=220 guifg=#e0af68
highlight Identifier ctermfg=220 guifg=#e0af68
highlight Delimiter ctermfg=240 guifg=#a9b1d6
highlight Operator ctermfg=220 guifg=#89ddff
highlight MatchParen ctermbg=24 ctermfg=214 guibg=#3d59a1 guifg=#e0af68
highlight Underlined cterm=underline gui=underline guifg=#7dcfff
highlight Ignore cterm=NONE guifg=NONE
highlight ErrorMsg ctermbg=52 ctermfg=196 guibg=#3d1f25 guifg=#f7768e
highlight ModeMsg ctermfg=220 guifg=#e0af68
highlight Question ctermfg=220 guifg=#e0af68
highlight MoreMsg ctermfg=220 guifg=#e0af68
highlight NonText ctermfg=240 guifg=#3b4261
highlight SpecialKey ctermfg=240 guifg=#3b4261
highlight Title ctermfg=222 guifg=#e0af68
highlight WildMenu ctermbg=24 guifg=#3d59a1
highlight qfLineNr ctermfg=240 guifg=#3b4261
highlight qfError ctermfg=196 guifg=#f7768e
highlight qfWarning ctermfg=214 guifg=#e0af68
highlight qfInfo ctermfg=39 guifg=#7dcfff
highlight qfNote ctermfg=220 guifg=#e0af68
