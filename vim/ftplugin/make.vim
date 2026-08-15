" ===================================
" Makefile 文件类型配置
" Spacemacs 风格：逗号 = Major Mode Local Leader
"   ,b = build (=make)   ,r = run (=make)
"   ,w = save            ,q = save&quit
" ===================================

" Makefile 严格要求 tab 缩进，绝不能 expandtab
setlocal noexpandtab
setlocal tabstop=4
setlocal shiftwidth=4
setlocal softtabstop=0

" 禁用自动缩进（Makefile 缩进有特殊语义）
setlocal nosmartindent
setlocal nocindent

" 语法高亮
syntax clear
syntax enable

" 构建快捷键（F* 保持兼容；同时提供逗号前缀的 Spacemacs 风格）
nnoremap <silent><buffer> <F5>          :w<CR>:make<CR>
nnoremap <silent><buffer> <Leader>rb    :w<CR>:make<CR>
" Spacemacs 本地 Leader 别名（,）
nnoremap <silent><buffer> <localleader>b :w<CR>:make<CR>
nnoremap <silent><buffer> <localleader>r :w<CR>:make<CR>
nnoremap <silent><buffer> <localleader>w :w<CR>
nnoremap <silent><buffer> <localleader>q :wq<CR>
