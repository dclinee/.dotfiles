" ===================================
" Makefile 文件类型配置
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

" 构建快捷键
nnoremap <buffer> <F5> :w<CR>:make<CR>
nnoremap <buffer> <Leader>rb :w<CR>:make<CR>
