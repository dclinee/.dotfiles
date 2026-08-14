" ===================================
" 插件配置
" ===================================

" vim-plug 自动安装：缺失时下载，下载失败静默跳过
let s:plug_path = expand('~/.vim/autoload/plug.vim')
if empty(glob(s:plug_path))
  if executable('curl')
    " 国内镜像优先，失败则直连官方；全部输出重定向到 /dev/null 避免干扰
    silent execute '!curl -fLo ' . s:plug_path . ' --create-dirs --connect-timeout 30 --max-time 60 -s -S https://ghproxy.net/https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim >/dev/null 2>&1'
    if !filereadable(s:plug_path)
      silent execute '!curl -fLo ' . s:plug_path . ' --create-dirs --connect-timeout 30 --max-time 60 -s -S https://gh-proxy.com/https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim >/dev/null 2>&1'
    endif
    if !filereadable(s:plug_path)
      silent execute '!curl -fLo ' . s:plug_path . ' --create-dirs --connect-timeout 30 --max-time 60 -s -S https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim >/dev/null 2>&1'
    endif
  endif
  if !filereadable(s:plug_path)
    " vim-plug 安装失败，跳过插件加载（不阻塞启动）
    finish
  endif
  " 首次进入 Vim 后自动安装插件
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" 插件列表
call plug#begin('~/.vim/plugged')

" 主题插件（LazyVim 风格配色，默认 Gruvbox + Tokyo Night 风格高亮）
Plug 'morhetz/gruvbox'             " Gruvbox（基础主题，确保可用）
Plug 'ghifarit53/tokyonight-vim'   " Tokyo Night（如网络可用则启用，模拟 LazyVim 风格）

" 语法高亮插件
Plug 'sheerun/vim-polyglot'        " 多语言语法高亮

" 自动补全插件（coc.nvim 统一接管 LSP，不再使用 jedi-vim 避免冲突）
Plug 'neoclide/coc.nvim', {'branch': 'release'}  " 智能补全 + LSP
Plug 'hrsh7th/vim-vsnip'           " 代码片段
Plug 'hrsh7th/vim-vsnip-integ'     " 代码片段集成

" 文件搜索插件
Plug 'junegunn/fzf', {'do': { -> fzf#install() }}  " 文件搜索
Plug 'junegunn/fzf.vim'            " FZF Vim 集成

" 代码导航插件
Plug 'preservim/tagbar'            " 标签导航（taglist.vim 已废弃，移除）

" Git 集成插件
Plug 'tpope/vim-fugitive'          " Git 集成
Plug 'airblade/vim-gitgutter'      " Git 状态显示

" 其他实用插件
Plug 'preservim/nerdcommenter'     " 代码注释
Plug 'preservim/nerdtree'          " 文件浏览器
Plug 'Xuyuanp/nerdtree-git-plugin' " Nerdtree Git 集成
Plug 'tiagofumo/vim-nerdtree-syntax-highlight' " Nerdtree 语法高亮
Plug 'ryanoasis/vim-devicons'      " 图标支持
Plug 'vim-airline/vim-airline'     " 状态栏增强
Plug 'vim-airline/vim-airline-themes' " Airline 主题
Plug 'terryma/vim-multiple-cursors' " 多光标编辑
Plug 'mbbill/undotree'             " 撤销树
Plug 'jiangmiao/auto-pairs'        " 自动括号匹配
Plug 'tpope/vim-surround'          " 环绕字符操作

" 语言特定插件（仅语法，补全交给 coc）
Plug 'rust-lang/rust.vim'          " Rust 支持
Plug 'pangloss/vim-javascript'     " JavaScript 支持
Plug 'maxmellon/vim-jsx-pretty'    " JSX 支持
Plug 'hashivim/vim-terraform'      " Terraform 支持
Plug 'fatih/vim-go'                " Go 支持

silent! call plug#end()

" ===================================
" 第三方插件错误抑制（Vim 9 兼容性问题）
" 这些错误来自 coc.nvim、vim-fugitive 等插件的 \ 行续语法
" cmdheight=2 让错误消息显示在第二行而不是阻塞
" ===================================
set cmdheight=2

" Nerdtree 配置（与 lua/dotfiles_modules/plugins/ui.lua 保持一致）
let NERDTreeShowHidden = 1
let NERDTreeIgnore = ['.git', 'node_modules', '.cache', '.venv', '__pycache__']
let NERDTreeShowLineNumbers = 1
let NERDTreeAutoDeleteBuffer = 1
nnoremap <Leader>n :NERDTreeToggle<CR>
" 自动打开 Nerdtree 当未指定文件时
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 0 && !exists('s:std_in') | NERDTree | endif

" Tagbar 配置
let g:tagbar_autoclose = 1
let g:tagbar_width = 30
nnoremap <Leader>t :TagbarToggle<CR>

" Coc.nvim 配置
" 注意：coc_global_extensions 列表只是声明，coc 不会自动安装
" 这里通过 VimEnter autocmd 在首次启动时触发安装
" Vim 9 不支持 \ 行续，全部写在一行内
let g:coc_global_extensions = split('coc-json coc-pyright coc-java coc-html coc-css coc-tsserver coc-vimlsp coc-go coc-rust-analyzer coc-snippets coc-markdownlint coc-prettier coc-yaml coc-toml coc-sh coc-docker coc-terraform coc-lua coc-spell-checker', ' ')

" 首次启动自动安装缺失的 coc 扩展（仅执行一次）
" 使用持久化标记文件避免重复触发；标记在安装函数末尾写入，首次失败后下次仍会重试
let s:coc_install_flag = expand('~/.cache/vim/.coc_extensions_installed')
if !filereadable(s:coc_install_flag) && exists(':CocInstall')
  autocmd VimEnter * call timer_start(2000, {-> s:CocInstallExtensions()})
endif
function! s:CocInstallExtensions() abort
  if !exists(':CocInstall')
    return
  endif
  let l:missing = []
  for l:ext in g:coc_global_extensions
    let l:dir = expand('~/.config/coc/extensions/node_modules/' . l:ext)
    if !isdirectory(l:dir)
      call add(l:missing, l:ext)
    endif
  endfor
  if !empty(l:missing)
    echohl WarningMsg
    echom '[dotfiles] 正在安装 coc 扩展: ' . join(l:missing, ' ')
    echohl None
    execute 'CocInstall ' . join(l:missing, ' ')
  endif
  " 不管是否有缺失，最后写标记：避免每次启动都扫描 node_modules
  call writefile(['done'], s:coc_install_flag)
endfunction

" Airline 配置（Tokyo Night 风格）
let g:airline_powerline_fonts = 1
let g:airline_theme = 'tokyonight'
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#fnamemod = ':t'

" Tokyo Night 主题配置（LazyVim 风格）
let g:tokyonight_style = 'night'
let g:tokyonight_enable_italic = 1
let g:tokyonight_disable_background = 1
let g:tokyonight_disable_float_background = 1
let g:tokyonight_highlight_functions = 'italic'
let g:tokyonight_highlight_strings = 'italic'
let g:tokyonight_highlight_variables = 'italic'
let g:tokyonight_highlight_properties = 'italic'
let g:tokyonight_highlight_keywords = 'italic'
let g:tokyonight_highlight_special = 'italic'
let g:tokyonight_highlight_comments = 'italic'
let g:tokyonight_highlight_codelit = 'bold'

" Fugitive 配置
nnoremap <Leader>gs :G<CR>
nnoremap <Leader>gc :G commit<CR>
nnoremap <Leader>gb :G blame<CR>
nnoremap <Leader>gp :G push<CR>
nnoremap <Leader>gl :G log<CR>

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

" FZF 配置
nnoremap <Leader>ff :Files<CR>
nnoremap <Leader>fg :GFiles<CR>
nnoremap <Leader>fb :Buffers<CR>
nnoremap <Leader>fs :Rg<CR>
