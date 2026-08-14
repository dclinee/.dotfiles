--[[
  Dotfiles Neovim 模块 — plugins/init.lua
  参照 LazyVim 的 lua/config/lazy.lua：负责 lazy.nvim 的 bootstrap 与 setup。

  启用仅在 g:dotfiles_use_lazy_nvim == 1 时触发；
  否则与现有 vim-plug 并行不相交（不冲突，不破坏）。
]]

local Util = require('dotfiles_modules.util')

local M = {}

--- lazy.nvim 自动安装（国内镜像回退，与 vim-plug 安装镜像保持一致的策略）
local function bootstrap()
  local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
  if vim.fn.isdirectory(lazypath) == 1 then
    vim.opt.rtp:prepend(lazypath)
    return true
  end

  -- 镜像列表（项目一致的 3 级策略：官方 → ghproxy.net → gh-proxy.com）
  -- 可通过 NO_MIRROR 环境变量跳过镜像
  local no_mirror = (vim.env.NO_MIRROR and vim.env.NO_MIRROR ~= '') and true or false
  local repos = no_mirror and {
    'https://github.com/folke/lazy.nvim.git',
  } or {
    'https://github.com/folke/lazy.nvim.git',
    'https://ghfast.top/https://github.com/folke/lazy.nvim.git',
    'https://mirror.ghproxy.com/https://github.com/folke/lazy.nvim.git',
  }

  Util.debug('lazy.nvim 未安装，开始 bootstrap...')
  local cloned = false
  for _, url in ipairs(repos) do
    local rv = vim.fn.system({
      'git', 'clone', '--filter=blob:none', url, '--branch=stable', lazypath,
    })
    if vim.v.shell_error == 0 and vim.fn.isdirectory(lazypath) == 1 then
      cloned = true
      break
    end
    vim.fn.delete(lazypath, 'rf') -- 失败清理
    Util.debug(string.format('  clone 失败: %s (exit=%s)', url, vim.v.shell_error))
  end

  if cloned then
    vim.opt.rtp:prepend(lazypath)
    Util.debug('lazy.nvim bootstrap 完成')
    return true
  else
    vim.schedule(function()
      vim.notify(
        '[dotfiles] lazy.nvim bootstrap 失败，保持现有 vim-plug 管理。\n' ..
        '可手动: git clone --filter=blob-none https://github.com/folke/lazy.nvim.git ' ..
        '--branch=stable ~/.local/share/nvim/lazy/lazy.nvim',
        vim.log.levels.WARN,
        { title = 'dotfiles_modules' }
      )
    end)
    return false
  end
end

function M.setup()
  if vim.fn.has('nvim-0.9') ~= 1 then
    -- lazy.nvim 要求 nvim-0.9+
    return
  end
  if not bootstrap() then
    return
  end

  local ok, lazy = pcall(require, 'lazy')
  if not ok then
    return
  end

  -- 收集 plugins/ 目录下所有 *.lua 的 spec（LazyVim 自动按文件加载约定）
  -- 注：{ import = 'dotfiles_modules.plugins' } 已自动递归加载该目录下所有子模块，无需手动循环追加
  local specs = { { import = 'dotfiles_modules.plugins' } }

  -- 同时加载 user/plugins/*.lua（用户自定义）
  if Util.has_module('user.plugins') then
    table.insert(specs, { import = 'user.plugins' })
  end

  lazy.setup(specs, {
    root = vim.fn.stdpath('data') .. '/lazy',
    defaults = {
      lazy = true,                -- LazyVim 默认: 插件一律懒加载
      version = false,            -- 不 pin tag，跟随最新
    },
    install = {
      colorscheme = { 'tokyonight', 'gruvbox', 'default' }, -- 与 Vimscript 保持一致
    },
    checker = {
      enabled = false,           -- 不自动检查更新，与 vim-plug 手动 PlugUpdate 保持一致
    },
    performance = {
      rtp = {
        -- 不要禁用已有 rtp，以免破坏 vim-plug 已安装插件
        disabled_plugins = {
          'gzip', 'tarPlugin', 'zipPlugin', 'tutor', 'tohtml',
        },
      },
    },
  })
end

return M
