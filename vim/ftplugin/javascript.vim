" ===================================
" JavaScript / TypeScript 文件类型配置
" Spacemacs 风格：逗号 = Major Mode Local Leader
"   ,r = run (node)   ,f = format   ,w = save   ,q = save&quit
" ===================================

" 主流 JS 风格：2 空格缩进
setlocal tabstop=2
setlocal softtabstop=2
setlocal shiftwidth=2
setlocal expandtab

" 文件末尾换行
setlocal endofline

" ESLint 修复快捷键（依赖 coc-prettier / coc-eslint）
nnoremap <silent><buffer> <Leader>rf    :call CocAction('format')<CR>

" 运行 Node.js（F* 保持兼容；同时提供逗号前缀的 Spacemacs 风格）
nnoremap <silent><buffer> <F5>          :w<CR>:!node %<CR>
" Spacemacs 本地 Leader 别名（,）
nnoremap <silent><buffer> <localleader>r :w<CR>:!node %<CR>
nnoremap <silent><buffer> <localleader>f :call CocAction('format')<CR>
nnoremap <silent><buffer> <localleader>w :w<CR>
nnoremap <silent><buffer> <localleader>q :wq<CR>
