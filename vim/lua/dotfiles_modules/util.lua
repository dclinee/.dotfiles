--[[
  Dotfiles Neovim 模块 — 工具函数库
  参照 LazyVim 的 util.lua：提供跨平台路径、日志、模块探测等基础能力
]]

local M = {}

--- 获取 dotfiles/vim 模块根目录（绝对路径）
---@return string
function M.mod_root()
  local info = debug.getinfo(1, 'S').source:sub(2) -- 去掉 '@'
  -- info = .../vim/lua/dotfiles_modules/util.lua → 上两级 = vim/
  return vim.fn.fnamemodify(info, ':p:h:h:h')
end

--- 列出目录下所有 *.lua 文件（按字母排序），不含子目录
---@param root string 绝对路径目录
---@return string[]  文件绝对路径列表
function M.glob_lua(root)
  if not vim.fn.isdirectory(root) then
    return {}
  end
  local files = vim.fn.glob(root .. '/*.lua', false, true) or {}
  table.sort(files)
  return files
end

--- 判断一个 Lua 模块是否存在可加载（不执行 require，无副作用）
---@param name string
---@return boolean
function M.has_module(name)
  for _, pat in ipairs(vim.api.nvim_get_runtime_file('lua/' .. name .. '.lua', true) or {}) do
    if vim.fn.filereadable(pat) == 1 then
      return true
    end
  end
  for _, pat in ipairs(vim.api.nvim_get_runtime_file('lua/' .. name .. '/init.lua', true) or {}) do
    if vim.fn.filereadable(pat) == 1 then
      return true
    end
  end
  return false
end

--- 调试级别日志（仅在 g:dotfiles_modules_debug=1 时显示）
---@param msg string
function M.debug(msg)
  if vim.g.dotfiles_modules_debug == 1 or vim.g.dotfiles_modules_debug == true then
    vim.schedule(function()
      vim.notify('[dotfiles] ' .. msg, vim.log.levels.DEBUG, { title = 'dotfiles_modules' })
    end)
  end
end

--- LazyVim 风格的键映射包装：统一 { silent = true } 默认 + noremap 默认
--- 用法：Util.map('n', '<leader>w', ':w<CR>')  /  Util.map({ {'n','v'}, '<leader>y', '"+y' })
function M.map(mode, lhs, rhs, opts)
  opts = opts or {}
  opts.silent = opts.silent ~= false
  if opts.remap and not vim.g.vscode then
    opts.remap = nil
  end
  vim.keymap.set(mode, lhs, rhs, opts)
end

--- 简化的 autocmd 创建（LazyVim Util.autocmd 风格）
---@param event string|table
---@param opts table
function M.autocmd(event, opts)
  opts = opts or {}
  local group = opts.group
  if type(group) == 'string' then
    opts.group = vim.api.nvim_create_augroup(group, { clear = true })
  end
  return vim.api.nvim_create_autocmd(event, opts)
end

return M
