" ===================================
" Go 文件类型配置
" Spacemacs 风格：逗号 = Major Mode Local Leader
"   ,r = run     ,b = build    ,t = test
"   ,w = save    ,q = save&quit
" ===================================

" Go 官方规范：使用 tab 缩进
setlocal noexpandtab
setlocal tabstop=4
setlocal shiftwidth=4
setlocal softtabstop=4

" Go 使用 gofmt 自动格式化（vim-go 集成）
let g:go_fmt_autosave = 1
let g:go_fmt_command = 'goimports'

" 保存时自动导入包
let g:go_imports_autosave = 1

" 运行 / 测试快捷键（F* 保持兼容；同时提供逗号前缀的 Spacemacs 风格）
nnoremap <silent><buffer> <F5>          :w<CR>:GoRun %<CR>
nnoremap <silent><buffer> <Leader>rt    :w<CR>:GoTest<CR>
nnoremap <silent><buffer> <Leader>rb    :w<CR>:GoBuild<CR>
" Spacemacs 本地 Leader 别名（,）
nnoremap <silent><buffer> <localleader>r :w<CR>:GoRun %<CR>
nnoremap <silent><buffer> <localleader>b :w<CR>:GoBuild<CR>
nnoremap <silent><buffer> <localleader>t :w<CR>:GoTest<CR>
nnoremap <silent><buffer> <localleader>w :w<CR>
nnoremap <silent><buffer> <localleader>q :wq<CR>
