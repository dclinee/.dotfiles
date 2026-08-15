" ===================================
" Python 文件类型配置
" Spacemacs 风格：逗号 = Major Mode Local Leader
"   ,r = run(=build)   ,b = run   ,f = format
"   ,w = save          ,q = save&quit
" ===================================

" PEP 8 规范：4 空格缩进
setlocal tabstop=4
setlocal softtabstop=4
setlocal shiftwidth=4
setlocal expandtab
setlocal textwidth=88

" 自动换行使用 PEP 8 风格
setlocal colorcolumn=88

" 文件头自动插入（仅新文件）
if line('$') == 1 && getline(1) == ''
  call setline(1, '#!/usr/bin/env python3')
  call setline(2, '# -*- coding: utf-8 -*-')
  call setline(3, '')
endif

" 编译/运行快捷键（F* 保持兼容；同时提供逗号前缀的 Spacemacs 风格）
nnoremap <silent><buffer> <F5>          :w<CR>:!python3 %<CR>
nnoremap <silent><buffer> <Leader>rb    :w<CR>:!python3 %<CR>
" Spacemacs 本地 Leader 别名（,）
nnoremap <silent><buffer> <localleader>r :w<CR>:!python3 %<CR>
nnoremap <silent><buffer> <localleader>b :w<CR>:!python3 %<CR>
nnoremap <silent><buffer> <localleader>f :call CocAction('format')<CR>
nnoremap <silent><buffer> <localleader>w :w<CR>
nnoremap <silent><buffer> <localleader>q :wq<CR>
