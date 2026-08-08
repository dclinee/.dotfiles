" ===================================
" Vim 配置主入口
" ===================================

" 设置 cmdheight=2 防止第三方插件错误阻塞启动
" 这是 LazyVim 风格的设置
set cmdheight=2

" 基础配置目录
let g:dotfiles_vim_dir = expand('~/.dotfiles/vim')

" 将 dotfiles/vim 加入 runtimepath，使 ftplugin/after 等子目录生效
let &runtimepath = g:dotfiles_vim_dir . ',' . &runtimepath

" 先加载插件配置（确保插件在核心配置之前加载）
if filereadable(g:dotfiles_vim_dir . '/plugins/plugins.vim')
  source ~/.dotfiles/vim/plugins/plugins.vim
endif

" 加载核心配置
for f in sort(split(glob(g:dotfiles_vim_dir . '/core/*.vim'), '\n'))
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

" 加载本地自定义配置（不会被仓库覆盖）
if filereadable(expand('~/.vimrc.local'))
  source ~/.vimrc.local
endif
