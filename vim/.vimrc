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

" ===================================
" 加载本地自定义配置（不会被仓库覆盖）
" 若要禁用 Lua 模块或切换插件管理器，在此文件中提前设置变量：
"   let g:dotfiles_enable_lua_modules = 0  " 完全禁用 Neovim Lua 叠加层
"   let g:dotfiles_use_lazy_nvim    = 1  " 启用 lazy.nvim 管理 plugins/*.lua（默认继续使用 vim-plug）
"   let g:dotfiles_lsp_provider     = 'nvim'  " 切换到 nvim-lspconfig（默认 coc.nvim）
" ===================================
if filereadable(expand('~/.vimrc.local'))
  source ~/.vimrc.local
endif

" ===================================
" Neovim Lua 模块（LazyVim 风格叠加层，零破坏性可选加载）
" - 仅 Neovim (has('nvim')) 下加载
" - 通过 let g:dotfiles_enable_lua_modules = 0 一键完全禁用
" - 现有 Vimscript 配置 (core/plugins/ftplugin/platform) 完全不受影响
" ===================================
if !exists('g:dotfiles_enable_lua_modules')
  let g:dotfiles_enable_lua_modules = 1
endif
if g:dotfiles_enable_lua_modules != 0 && has('nvim') && isdirectory(g:dotfiles_vim_dir . '/lua')
  try
    " 将 lua/ 所在目录加入 &runtimepath，使得 require('dotfiles_modules') 可被找到
    execute 'set runtimepath^=' . g:dotfiles_vim_dir
    lua << EOF
      local ok, err = pcall(function()
        local m = require('dotfiles_modules')
        if m and type(m.setup) == 'function' then
          m.setup()
        end
      end)
      if not ok then
        vim.schedule(function()
          vim.notify(
            '[dotfiles] Lua 模块加载失败（已安全跳过）: ' .. tostring(err) ..
            '\n在 ~/.vimrc.local 中设置 let g:dotfiles_enable_lua_modules = 0 可关闭',
            vim.log.levels.WARN,
            { title = 'dotfiles_modules' }
          )
        end)
      end
EOF
  catch
    " 任何异常都不阻塞启动（保持 Vim 9 + 旧环境兼容）
    echohl WarningMsg
    echom '[dotfiles] Lua 模块初始化异常，已安全跳过（不受影响）'
    echohl None
  endtry
endif
