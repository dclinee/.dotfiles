--[[
  user/init.example.lua — 用户自定义入口示例
  使用: cp user/init.example.lua user/init.lua 然后按需修改

  本文件在 dotfiles_modules 全部加载完成后执行，
  因此可以**覆盖**仓库里的任何设置。
]]

local Util = require('dotfiles_modules.util')
local map = Util.map

-- =========================================
--  示例 1: 覆盖默认选项
-- =========================================
-- vim.opt.relativenumber = false  -- 关闭相对行号
-- vim.opt.shiftwidth = 2          -- 默认缩进改为 2 空格

-- =========================================
--  示例 2: 追加自定义快捷键
-- =========================================
-- map('n', '<leader>qq', '<cmd>qa<cr>', { desc = 'Quit all' })
-- map('n', '<leader>pp', '<cmd>pwd<cr>', { desc = 'Print cwd' })

-- =========================================
--  示例 3: 自定义自动命令
-- =========================================
-- Util.autocmd('FileType', {
--   group = 'user_md_fold',
--   pattern = 'markdown',
--   callback = function() vim.opt_local.foldmethod = 'expr' end,
-- })

local M = {}

function M.setup()
  -- 在这里放置你的代码：
  -- vim.notify('user.init loaded!', vim.log.levels.INFO)
end

return M
