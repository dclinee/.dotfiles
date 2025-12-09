" ===================================
" 插件配置
" ===================================

" 插件管理器配置
" 使用 Vim-plug 作为插件管理器
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" 插件列表
call plug#begin('~/.vim/plugged')

" 主题插件
Plug 'morhetz/gruvbox'             " Gruvbox 主题
Plug 'solarized/vim'               " Solarized 主题
Plug 'tomasr/molokai'              " Molokai 主题
Plug 'dracula/vim'                 " Dracula 主题

" 语法高亮插件
Plug 'sheerun/vim-polyglot'        " 多语言语法高亮

" 自动补全插件
Plug 'neoclide/coc.nvim', {'branch': 'release'}  " 智能补全
Plug 'hrsh7th/vim-vsnip'           " 代码片段
Plug 'hrsh7th/vim-vsnip-integ'     " 代码片段集成

" 文件搜索插件
Plug 'junegunn/fzf', {'do': { -> fzf#install() }}  " 文件搜索
Plug 'junegunn/fzf.vim'            " FZF Vim 集成

" 代码导航插件
Plug 'preservim/tagbar'            " 标签导航
Plug 'vim-scripts/taglist.vim'     " 标签列表

" Git 集成插件
Plug 'tpope/vim-fugitive'          " Git 集成
Plug 'airblade/vim-gitgutter'      " Git 状态显示

" 其他实用插件
Plug 'preservim/nerdcommenter'     " 代码注释
Plug 'scrooloose/nerdtree'         " 文件浏览器
Plug 'Xuyuanp/nerdtree-git-plugin' " Nerdtree Git 集成
Plug 'tiagofumo/vim-nerdtree-syntax-highlight' " Nerdtree 语法高亮
Plug 'ryanoasis/vim-devicons'      " 图标支持
Plug 'vim-airline/vim-airline'     " 状态栏增强
Plug 'vim-airline/vim-airline-themes' " Airline 主题
Plug 'terryma/vim-multiple-cursors' " 多光标编辑
Plug 'mbbill/undotree'             " 撤销树
Plug 'jiangmiao/auto-pairs'        " 自动括号匹配
Plug 'tpope/vim-surround'          " 环绕字符操作

" 语言特定插件
Plug 'davidhalter/jedi-vim'        " Python 补全
Plug 'rust-lang/rust.vim'          " Rust 支持
Plug 'pangloss/vim-javascript'     " JavaScript 支持
Plug 'maxmellon/vim-jsx-pretty'    " JSX 支持
Plug 'hashivim/vim-terraform'      " Terraform 支持
Plug 'fatih/vim-go'                " Go 支持

call plug#end()

" 插件配置

" Nerdtree 配置
let NERDTreeShowHidden = 1
let NERDTreeIgnore = ['.git', 'node_modules', '.cache', '.venv']
let NERDTreeShowLineNumbers = 1
let NERDTreeAutoDeleteBuffer = 1
nnoremap <Leader>n :NERDTreeToggle<CR>

" Tagbar 配置
let g:tagbar_autoclose = 1
let g:tagbar_width = 30
nnoremap <Leader>t :TagbarToggle<CR>

" Coc.nvim 配置
let g:coc_global_extensions = [
  \'coc-json\',
  \'coc-python\',
  \'coc-java\',
  \'coc-html\',
  \'coc-css\',
  \'coc-javascript\',
  \'coc-typescript\',
  \'coc-vimlsp\',
  \'coc-go\',
  \'coc-rust-analyzer\',
  \'coc-snippets\',
  \'coc-markdownlint\',
  \'coc-prettier\',
  \'coc-yaml\',
  \'coc-toml\',
  \'coc-sh\',
  \'coc-docker\',
  \'coc-terraform\',
  \'coc-lua\',
  \'coc-spell-checker\'
]

" Airline 配置
let g:airline_powerline_fonts = 1
let g:airline_theme = 'gruvbox'
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#fnamemod = ':t'

" Fugitive 配置
nnoremap <Leader>gs :G<CR>
noremap <Leader>gc :G commit<CR>
noremap <Leader>gb :G blame<CR>
noremap <Leader>gp :G push<CR>
noremap <Leader>gl :G log<CR>

" Undotree 配置
nnoremap <Leader>u :UndotreeToggle<CR>
let g:undotree_WindowLayout = 2
let g:undotree_SetFocusWhenToggle = 1

" Vim-surround 配置
" 使用 cs<char1><char2> 替换环绕字符
" 使用 ds<char> 删除环绕字符
" 使用 ys<motion><char> 添加环绕字符

" GitGutter 配置
let g:gitgutter_sign_added = '+'
let g:gitgutter_sign_modified = '~'
let g:gitgutter_sign_removed = '-'

" NerdCommenter 配置
let g:NERDSpaceDelims = 1
let g:NERDDefaultAlign = 'left'
let g:NERDCommentEmptyLines = 1
let g:NERDTrimTrailingWhitespace = 1

" 自动安装插件
" 首次打开 Vim 时自动安装插件
if !exists('g:plug_installed')
  let g:plug_installed = 1
  PlugInstall
endif
