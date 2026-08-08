" ===================================
" Python 文件类型配置
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

" 编译/运行快捷键
nnoremap <buffer> <F5> :w<CR>:!python3 %<CR>
nnoremap <buffer> <Leader>rb :w<CR>:!python3 %<CR>
