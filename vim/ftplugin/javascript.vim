" ===================================
" JavaScript / TypeScript 文件类型配置
" ===================================

" 主流 JS 风格：2 空格缩进
setlocal tabstop=2
setlocal softtabstop=2
setlocal shiftwidth=2
setlocal expandtab

" 文件末尾换行
setlocal endofline

" ESLint 修复快捷键（依赖 coc-prettier / coc-eslint）
nnoremap <buffer> <Leader>rf :call CocAction('format')<CR>

" 运行 Node.js
nnoremap <buffer> <F5> :w<CR>:!node %<CR>
