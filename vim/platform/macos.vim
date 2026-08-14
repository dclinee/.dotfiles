" ===================================
" macOS 平台特定配置
" ===================================

" macOS 使用 pbcopy/pbpaste 作为系统剪贴板
set clipboard=unnamedplus

" macOS 默认 GUI Vim 已带剪贴板支持，终端 Vim 通过 pbcopy 桥接
if !has('clipboard') && executable('pbcopy')
  let g:clipboard = {'name': 'macos-clipboard', 'copy': {'+': 'pbcopy', '*': 'pbcopy'}, 'paste': {'+': 'pbpaste', '*': 'pbpaste'}, 'cache_enabled': 1}
endif

" macOS 默认 Vim 可能不带 Python，避免加载失败
if !has('python3') && !has('python')
  let g:loaded_python_provider = 0
  let g:loaded_python3_provider = 0
endif

" macOS 终端默认 $TERM=xterm-256color，启用真彩色（在 core 通用判断基础上，针对 macOS 常见终端补保险）
if $TERM_PROGRAM ==# 'iTerm.app' || $TERM_PROGRAM ==# 'Apple_Terminal'
  set termguicolors
endif
