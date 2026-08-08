" ===================================
" Rust 文件类型配置
" ===================================

" Rust 官方风格：4 空格缩进
setlocal tabstop=4
setlocal softtabstop=4
setlocal shiftwidth=4
setlocal expandtab
setlocal textwidth=100

" 显示第 100 列参考线（Rust 风格指南推荐 100 字符）
setlocal colorcolumn=100

" 保存时自动格式化（需要 rustfmt，已随 rustup 安装）
let g:rustfmt_autosave = 1
let g:rustfmt_options = '--edition 2021'

" rust.vim 插件配置
let g:rust_clip_command = 'xclip -selection clipboard'
let g:rust_fold = 1                    " 代码折叠
let g:rust_recommended_style = 1       " 使用推荐缩进风格

" 编译/运行/测试快捷键
nnoremap <buffer> <F5> :w<CR>:Cargo run<CR>
nnoremap <buffer> <Leader>rb :w<CR>:Cargo build<CR>
nnoremap <buffer> <Leader>rr :w<CR>:Cargo run<CR>
nnoremap <buffer> <Leader>rt :w<CR>:Cargo test<CR>
nnoremap <buffer> <Leader>rc :w<CR>:Cargo clippy<CR>
nnoremap <buffer> <Leader>rf :w<CR>:RustFmt<CR>
nnoremap <buffer> <Leader>rd :Cargo doc --open<CR>

" Coc-rust-analyzer 快捷键
" 覆盖通用快捷键，提供 Rust 专属操作
nnoremap <buffer> <Leader>ca :CocAction<CR>           " 代码操作
nnoremap <buffer> <Leader>cr :CocCommand rust-analyzer.run<CR>  " 运行
nnoremap <buffer> <Leader>cd :CocCommand rust-analyzer.debug<CR> " 调试
nnoremap <buffer> <Leader>ce :CocCommand rust-analyzer.expandMacro<CR> " 展开宏
nnoremap <buffer> <Leader>cg :CocCommand rust-analyzer.parentModule<CR> " 跳转到父模块
nnoremap <buffer> <Leader>cm :CocCommand rust-analyzer.moveItem<CR>  " 移动项
