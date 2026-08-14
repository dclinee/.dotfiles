" ===================================
" Go 文件类型配置
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

" 运行 / 测试快捷键
nnoremap <silent><buffer> <F5> :w<CR>:GoRun %<CR>
nnoremap <silent><buffer> <Leader>rt :w<CR>:GoTest<CR>
nnoremap <silent><buffer> <Leader>rb :w<CR>:GoBuild<CR>
