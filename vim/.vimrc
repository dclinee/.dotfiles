" ===================================
" Vim 配置主入口
" ===================================

" 基础配置目录
let g:dotfiles_vim_dir = expand('~/.dotfiles/vim')

" 加载核心配置
for f in split(glob(g:dotfiles_vim_dir . '/core/*.vim'), '\n')
  execute 'source' f
endfor

" 加载平台特定配置
if has('macunix')
  if filereadable(g:dotfiles_vim_dir . '/platform/macos.vim')
    source ~/.dotfiles/vim/platform/macos.vim
  endif
elseif has('win32')
  if filereadable(g:dotfiles_vim_dir . '/platform/windows.vim')
    source ~/.dotfiles/vim/platform/windows.vim
  endif
else
  if filereadable(g:dotfiles_vim_dir . '/platform/linux.vim')
    source ~/.dotfiles/vim/platform/linux.vim
  endif
endif

" 加载插件配置
if filereadable(g:dotfiles_vim_dir . '/plugins/plugins.vim')
  source ~/.dotfiles/vim/plugins/plugins.vim
endif

" 加载本地自定义配置（不会被仓库覆盖）
if filereadable(expand('~/.vimrc.local'))
  source ~/.vimrc.local
endif
