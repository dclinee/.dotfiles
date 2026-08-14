" ===================================
" Linux 平台特定配置
" ===================================

" 系统剪贴板：Linux 通常使用 xclip / xsel
" 若 +clipboard 未编译，回退到 xclip 工具
if has('clipboard')
  set clipboard=unnamedplus
endif

" 使用 xclip 作为剪贴板后备（无 +clipboard 编译时）
if !has('clipboard') && executable('xclip')
  let g:clipboard = {'name': 'xclip', 'copy': {'+': 'xclip -selection clipboard', '*': 'xclip -selection primary'}, 'paste': {'+': 'xclip -selection clipboard -o', '*': 'xclip -selection primary -o'}, 'cache_enabled': 1}
endif

" GTK GNOME 终端下避免背景色错误（补充 termguicolors：与 core/00_basic.vim、platform/macos.vim 构成分层设置，均幂等）
if $TERM =~? 'gnome'
  set termguicolors
endif
