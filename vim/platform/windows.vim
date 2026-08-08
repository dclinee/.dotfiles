" ===================================
" Windows 平台特定配置（含 WSL2）
" ===================================

" Windows 原生 Vim 与 WSL Vim 共用此文件
" 剪贴板：Win32 用 *，WSL 用 win32yank.exe 或 clip.exe
if has('win32')
  set clipboard=unnamed
elseif has('unix') && executable('win32yank.exe')
  " WSL2 环境：使用 win32yank.exe 桥接 Windows 剪贴板
  let g:clipboard = {'name': 'win32yank', 'copy': {'+': 'win32yank.exe -i --crlf', '*': 'win32yank.exe -i --crlf'}, 'paste': {'+': 'win32yank.exe -o --crlf', '*': 'win32yank.exe -o --crlf'}, 'cache_enabled': 0}
elseif has('unix') && executable('clip.exe')
  " WSL2 备用方案：clip.exe（仅复制）
  let g:clipboard = {'name': 'wsl-clip', 'copy': {'+': 'clip.exe', '*': 'clip.exe'}, 'paste': {'+': '', '*': ''}, 'cache_enabled': 0}
endif

" Windows 文件路径使用反斜杠，避免乱码
if has('win32')
  set shellslash
endif

" Windows 控制台默认编码处理
if has('win32')
  set encoding=utf-8
  let $LANG = 'en_US.UTF-8'
endif
