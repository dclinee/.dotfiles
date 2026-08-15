" ===================================
" Rust 文件类型配置
" Spacemacs 风格：逗号 = Major Mode Local Leader
"   ,r=run  ,b=build  ,t=test   ,c=clippy  ,f=fmt    ,d=doc
"   ,ca=code action  ,cr=run(RA) ,cd=debug(RA)  ,ce=expand macro
"   ,cg=parent module  ,cm=move item
"   ,w=save  ,q=save&quit
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

" 编译/运行/测试快捷键（F* 保持兼容；同时提供逗号前缀的 Spacemacs 风格）
nnoremap <silent><buffer> <F5>          :w<CR>:Cargo run<CR>
nnoremap <silent><buffer> <Leader>rb    :w<CR>:Cargo build<CR>
nnoremap <silent><buffer> <Leader>rr    :w<CR>:Cargo run<CR>
nnoremap <silent><buffer> <Leader>rt    :w<CR>:Cargo test<CR>
nnoremap <silent><buffer> <Leader>rc    :w<CR>:Cargo clippy<CR>
nnoremap <silent><buffer> <Leader>rf    :w<CR>:RustFmt<CR>
nnoremap <silent><buffer> <Leader>rd    :Cargo doc --open<CR>

" Spacemacs 本地 Leader 别名（,）
nnoremap <silent><buffer> <localleader>b :w<CR>:Cargo build<CR>
nnoremap <silent><buffer> <localleader>r :w<CR>:Cargo run<CR>
nnoremap <silent><buffer> <localleader>t :w<CR>:Cargo test<CR>
nnoremap <silent><buffer> <localleader>c :w<CR>:Cargo clippy<CR>
nnoremap <silent><buffer> <localleader>f :w<CR>:RustFmt<CR>
nnoremap <silent><buffer> <localleader>d :Cargo doc --open<CR>
nnoremap <silent><buffer> <localleader>w :w<CR>
nnoremap <silent><buffer> <localleader>q :wq<CR>

" Coc-rust-analyzer 快捷键（覆盖通用快捷键，提供 Rust 专属操作）
nnoremap <silent><buffer> <Leader>ca :CocAction<CR>
nnoremap <silent><buffer> <Leader>cr :CocCommand rust-analyzer.run<CR>
nnoremap <silent><buffer> <Leader>cd :CocCommand rust-analyzer.debug<CR>
nnoremap <silent><buffer> <Leader>ce :CocCommand rust-analyzer.expandMacro<CR>
nnoremap <silent><buffer> <Leader>cg :CocCommand rust-analyzer.parentModule<CR>
nnoremap <silent><buffer> <Leader>cm :CocCommand rust-analyzer.moveItem<CR>
" Coc 系列也同步到逗号本地 Leader
nnoremap <silent><buffer> <localleader>ca :CocAction<CR>
nnoremap <silent><buffer> <localleader>cr :CocCommand rust-analyzer.run<CR>
nnoremap <silent><buffer> <localleader>cd :CocCommand rust-analyzer.debug<CR>
nnoremap <silent><buffer> <localleader>ce :CocCommand rust-analyzer.expandMacro<CR>
nnoremap <silent><buffer> <localleader>cg :CocCommand rust-analyzer.parentModule<CR>
nnoremap <silent><buffer> <localleader>cm :CocCommand rust-analyzer.moveItem<CR>
