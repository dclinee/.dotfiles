--[[
  Dotfiles Neovim 模块 — 主入口
  参照 LazyVim 框架的模块化结构：
    1. 先加载基础选项 options
    2. 再加载全局键位映射 keymaps
    3. 再加载自动命令 autocmds
    4. 若启用 lazy.nvim (g:dotfiles_use_lazy_nvim) 则初始化插件
    5. 最后加载 user/ 下的自定义（不入库）扩展

  本模块是可选叠加层：
    - 仅 Neovim (has('nvim')) 下加载
    - 通过 vim.g.dotfiles_enable_lua_modules = 0 一键完全禁用
    - 不替代原有 Vimscript 配置，只是追加/增强
]]

local Util = require('dotfiles_modules.util')

local M = {}

--- 加载单个子模块，失败时记录警告但不阻塞启动（LazyVim 容错风格）
local function safe_require(modname)
  local ok, mod = pcall(require, modname)
  if not ok then
    vim.schedule(function()
      vim.notify(
        string.format('[dotfiles] 模块加载失败: %s\n%s', modname, mod),
        vim.log.levels.WARN,
        { title = 'dotfiles_modules' }
      )
    end)
    return nil
  end
  return mod
end

--- 加载目录下所有子模块（按字母序，LazyVim plugins/ 约定）
---@param dir_name string  相对 dotfiles_modules 的子目录名，例如 "config" / "plugins"
local function load_all(dir_name)
  local mod_prefix = 'dotfiles_modules.' .. dir_name
  local root = Util.mod_root() .. '/lua/dotfiles_modules/' .. dir_name
  local files = Util.glob_lua(root)

  for _, file in ipairs(files) do
    local stem = vim.fn.fnamemodify(file, ':t:r')
    if stem ~= 'init' then
      safe_require(mod_prefix .. '.' .. stem)
    end
  end
  -- init.lua 最后加载，保证依赖齐全
  safe_require(mod_prefix .. '.init')
end

function M.setup()
  -- 0) 前置保护：用户显式禁用
  if vim.g.dotfiles_enable_lua_modules == 0 or vim.g.dotfiles_enable_lua_modules == false then
    return
  end

  -- 1) 基础选项（vim.opt 风格，先于一切加载）
  safe_require('dotfiles_modules.config.options')

  -- 2) 自动命令（在 keymaps 之前：部分映射依赖 autocmd 事件）
  safe_require('dotfiles_modules.config.autocmds')

  -- 3) 全局键位映射（LazyVim vim.keymap.set 规范）
  safe_require('dotfiles_modules.config.keymaps')

  -- 3.5) Which-Key：独立加载（不依赖 lazy.nvim）
  --   vim-plug 已通过 plugins.vim 安装 folke/which-key.nvim（仅 Neovim）
  --   若启用 lazy.nvim，ui.lua spec 的 config 也会调用此模块（幂等，不会重复 setup）
  if vim.fn.has('nvim') == 1 then
    local wk_mod = safe_require('dotfiles_modules.config.which-key')
    if wk_mod and type(wk_mod.setup) == 'function' then
      wk_mod.setup()
    end
  end

  -- 4) 可选：启用 lazy.nvim 插件管理
  --    默认为 0（与现有 vim-plug 和平共存，零破坏）
  --    用户在 ~/.vimrc.local 中: let g:dotfiles_use_lazy_nvim = 1 时启用
  if vim.g.dotfiles_use_lazy_nvim == 1 or vim.g.dotfiles_use_lazy_nvim == true then
    local lazy_init = safe_require('dotfiles_modules.plugins.init')
    if lazy_init and type(lazy_init.setup) == 'function' then
      lazy_init.setup()
      -- 加载 plugins/*.lua 中的所有 spec（LazyVim 按文件自动加载的约定）
      load_all('plugins')
    end
  end

  -- 5) 用户自定义扩展（~/.dotfiles/vim/lua/user/init.lua）
  --    user/ 目录下的内容不会被纳入版本控制（见 vim/.gitignore）
  if Util.has_module('user.init') then
    local user_ok, user_mod = pcall(require, 'user.init')
    if user_ok and type(user_mod.setup) == 'function' then
      user_mod.setup()
    end
  end

  -- 启动完成日志（仅 debug 级别，避免干扰启动输出）
  Util.debug('modules loaded (LazyVim-style overlay)')
end

return M
