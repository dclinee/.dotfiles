" ===================================
" 基础配置
" ===================================

" 设置Vim版本要求
if v:version < 800
  echo "警告: Vim版本过低，部分功能可能无法使用"
endif

" 关闭兼容性
set nocompatible

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

" 使用系统剪贴板
set clipboard=unnamedplus

" 启用语法高亮
syntax enable

" 自动缩进
set autoindent
set smartindent
set cindent

" 缩进设置
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

" 启用拼写检查（可选）
" set spell
" set spelllang=en_us,zh_cn

" 状态栏显示编码和文件类型
set statusline+=%F\ %m\ %r\ %y\ %{&fileencoding?&fileencoding:&encoding}\ %=\ %l,%c%V\ %P

" 配色方案
set background=dark
" 可以根据需要设置具体的配色方案，例如：
" colorscheme molokai
" colorscheme gruvbox
" colorscheme solarized
