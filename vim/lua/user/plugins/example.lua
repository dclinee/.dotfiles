--[[
  user/plugins/example.lua — LazyVim 风格插件 spec 示例

  使用方法：
    1) 确保在 ~/.vimrc.local 中: let g:dotfiles_use_lazy_nvim = 1
    2) cp user/plugins/example.lua user/plugins/my_plugins.lua
    3) 修改其中的插件列表

  本文件仅展示语法，默认不提供实际插件（保持仓库轻量）。
]]

--- @type LazySpec[]
return {

  -- 例 1: 添加一个简单插件，按键触发
  -- {
  --   'windwp/nvim-autopairs',
  --   event = 'InsertEnter',
  --   config = function()
  --     require('nvim-autopairs').setup({})
  --   end,
  -- },

  -- 例 2: 覆盖已有插件的 opts（例如 tokyonight 想换 style）
  -- {
  --   'folke/tokyonight.nvim',
  --   opts = { style = 'storm', transparent = true },
  -- },

  -- 例 3: 添加 formatter（LazyVim 常用）
  -- {
  --   'stevearc/conform.nvim',
  --   opts = {
  --     formatters_by_ft = {
  --       python = { 'ruff_format' },
  --       rust   = { 'rustfmt' },
  --     },
  --   },
  -- },
}
