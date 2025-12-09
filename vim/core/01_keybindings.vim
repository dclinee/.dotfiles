" ===================================
" 快捷键映射配置
" ===================================

" 映射空格为Leader键
let mapleader = " "
let g:mapleader = " "

" 保存和退出
nnoremap <Leader>w :w<CR>
nnoremap <Leader>q :q<CR>
nnoremap <Leader>wq :wq<CR>
nnoremap <Leader>qa :qa<CR>
nnoremap <Leader>q! :q!<CR>
nnoremap <Leader>wq! :wq!<CR>

" 窗口管理
nnoremap <Leader>sv :vsplit<CR>
noremap <Leader>sh :split<CR>
noremap <Leader>sc :close<CR>
noremap <Leader>so :only<CR>

" 窗口切换
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" 调整窗口大小
nnoremap <C-Up> :resize +2<CR>
noremap <C-Down> :resize -2<CR>
noremap <C-Left> :vertical resize -2<CR>
noremap <C-Right> :vertical resize +2<CR>

" 标签页管理
nnoremap <Leader>tn :tabnew<CR>
noremap <Leader>tc :tabclose<CR>
noremap <Leader>to :tabonly<CR>
noremap <Leader>tl :tabnext<CR>
noremap <Leader>th :tabprevious<CR>

" 标签页切换
nnoremap <S-l> :tabnext<CR>
noremap <S-h> :tabprevious<CR>

" 快速移动
nnoremap <Leader>j 8j
nnoremap <Leader>k 8k
nnoremap <Leader>h ^
noremap <Leader>l $

" 快速搜索
nnoremap <Leader>/ :nohlsearch<CR>

" 快速选中
vnoremap <Leader>a ggVG

" 快速复制
nnoremap <Leader>y 

" LSP 快捷键
" 跳转到定义
nnoremap <Leader>gd <Plug>(coc-definition)
" 跳转到声明
nnoremap <Leader>gD <Plug>(coc-declaration)
" 跳转到实现
nnoremap <Leader>gi <Plug>(coc-implementation)
" 跳转到类型定义
nnoremap <Leader>gt <Plug>(coc-type-definition)
" 查找引用
nnoremap <Leader>gr <Plug>(coc-references)
" 显示文档
nnoremap K :call CocActionAsync('doHover')<CR>
" 重命名
nnoremap <Leader>rn <Plug>(coc-rename)
" 代码操作
nnoremap <Leader>ca <Plug>(coc-codeaction-selected)
" 智能补全确认
inoremap <expr> <CR> pumvisible() ? coc#_select_confirm() : "\<CR>"
" 跳转到下一个诊断
nnoremap <Leader>] <Plug>(coc-diagnostic-next)
" 跳转到上一个诊断
nnoremap <Leader>[ <Plug>(coc-diagnostic-prev)