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
nnoremap <Leader>Q :q!<CR>

" 窗口管理（统一使用 nnoremap，仅在 normal 模式生效）
nnoremap <Leader>sv :vsplit<CR>
nnoremap <Leader>sh :split<CR>
nnoremap <Leader>sc :close<CR>
nnoremap <Leader>so :only<CR>

" 窗口切换
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" 调整窗口大小
nnoremap <C-Up> :resize +2<CR>
nnoremap <C-Down> :resize -2<CR>
nnoremap <C-Left> :vertical resize -2<CR>
nnoremap <C-Right> :vertical resize +2<CR>

" 标签页管理
nnoremap <Leader>tn :tabnew<CR>
nnoremap <Leader>tc :tabclose<CR>
nnoremap <Leader>to :tabonly<CR>
nnoremap <Leader>tl :tabnext<CR>
nnoremap <Leader>th :tabprevious<CR>

" 标签页快速切换
nnoremap <S-l> :tabnext<CR>
nnoremap <S-h> :tabprevious<CR>

" 快速移动（行内/垂直）
nnoremap <Leader>j 8j
nnoremap <Leader>k 8k
nnoremap <Leader>h ^
nnoremap <Leader>l $

" 清除搜索高亮
nnoremap <Leader>/ :nohlsearch<CR>

" 全选
vnoremap <Leader>a ggVG

" 复制到系统剪贴板（明确语义，原 <Leader>y 是空映射已删除）
nnoremap <Leader>y "+y
vnoremap <Leader>y "+y
nnoremap <Leader>Y "+Y

" 从系统剪贴板粘贴
nnoremap <Leader>p "+p
vnoremap <Leader>p "+p

" ===================================
" Coc.nvim LSP 快捷键
" ===================================

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
" 跳转到下一个诊断
nnoremap <Leader>] <Plug>(coc-diagnostic-next)
" 跳转到上一个诊断
nnoremap <Leader>[ <Plug>(coc-diagnostic-prev)

" ===================================
" 补全弹窗交互（关键：Tab/S-Tab 切换 + Enter 确认）
" ===================================

" 智能确认：补全弹窗可见时确认，否则原样换行
inoremap <expr> <CR> pumvisible() ? coc#_select_confirm() : "\<CR>"

" Tab 在补全弹窗中向下选择，否则原样 Tab
inoremap <expr> <Tab> pumvisible() ? "\<C-n>" : "\<Tab>"

" S-Tab 在补全弹窗中向上选择，否则原样 S-Tab
inoremap <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"

" ===================================
" 插件管理快捷键
" ===================================

nnoremap <Leader>pi :PlugInstall<CR>
nnoremap <Leader>pu :PlugUpdate<CR>
nnoremap <Leader>pc :PlugClean<CR>
nnoremap <Leader>ps :PlugStatus<CR>
