--[[
  Dotfiles Neovim 模块 — 全局键位映射 config/keymaps.lua
  完全遵循 LazyVim 的映射规范:
    1. 一律使用 vim.keymap.set (非 nnoremap/inoremap 等传统样式)
    2. 默认 { silent = true, noremap = true }
    3. 分组语义: <leader>f 文件/查找, <leader>g Git/LSP, <leader>s 窗口, <leader>u UI/杂项
    4. 不覆盖 Vimscript 01_keybindings.vim 中的已有映射（除非 LazyVim 分组冲突时显式避开）

  启用条件: has('nvim') + g:dotfiles_enable_lua_modules != 0
]]

local Util = require('dotfiles_modules.util')
local map = Util.map
local opt = vim.opt

-- =========================================
--  基础：保存/退出/清搜索 （与 Vimscript 重复映射安全：noremap 幂等）
-- =========================================
-- 保存
map({ 'i', 'v', 'n', 's' }, '<C-s>', '<cmd>w<cr><esc>', { desc = 'Save file' })
-- 强制退出
map('n', '<leader>Q', '<cmd>qa!<cr>', { desc = 'Quit all (!)' })
-- 清搜索（LazyVim 约定 <Esc> 清除 hlsearch）
map('n', '<Esc>', '<cmd>nohls<cr><esc>', { desc = 'Escape and clear hlsearch' })

-- =========================================
--  窗口管理（与 core/01_keybindings.vim 的 <C-hjkl> 共存；此处补 LazyVim 风格 <C-w> 快捷）
-- =========================================
map('n', '<leader>wv', '<C-w>v',    { desc = 'Split window vertically' })
map('n', '<leader>wh', '<C-w>s',    { desc = 'Split window horizontally' })
map('n', '<leader>we', '<C-w>=',    { desc = 'Equalize splits' })
map('n', '<leader>wc', '<C-w>c',    { desc = 'Close current window' })
map('n', '<leader>wo', '<C-w>o',    { desc = 'Close other windows' })

-- =========================================
--  标签页（LazyVim 分组 <leader><tab>）
-- =========================================
map('n', '<leader><tab><tab>', '<cmd>tabnew<cr>',       { desc = 'New tab' })
map('n', '<leader><tab>n',     '<cmd>tabnext<cr>',      { desc = 'Next tab' })
map('n', '<leader><tab>p',     '<cmd>tabprevious<cr>',  { desc = 'Prev tab' })
map('n', '<leader><tab>c',     '<cmd>tabclose<cr>',     { desc = 'Close tab' })
map('n', '<leader><tab>o',     '<cmd>tabonly<cr>',      { desc = 'Close other tabs' })

-- =========================================
--  LSP / Coc 运行时探测（按键时判断，不因加载时 Neovim 内置模块恒存在而误判）
-- =========================================
local function has_coc() return vim.fn.exists('*CocActionAsync') == 1 end

-- =========================================
--  LazyVim 风格的诊断跳转（映射到 [d / ]d，避免与 coc 的 <leader>[ / ] 冲突）
-- =========================================
map('n', ']d', function()
  if has_coc() then
    vim.fn['CocActionAsync']('diagnosticNext')
  elseif vim.diagnostic then
    vim.diagnostic.goto_next()
  end
end, { desc = 'Next diagnostic' })

map('n', '[d', function()
  if has_coc() then
    vim.fn['CocActionAsync']('diagnosticPrev')
  elseif vim.diagnostic then
    vim.diagnostic.goto_prev()
  end
end, { desc = 'Prev diagnostic' })

map('n', '<leader>cd', function()
  if has_coc() then
    vim.fn.CocActionAsync('diagnosticList')
  elseif vim.diagnostic then
    vim.diagnostic.open_float()
  end
end, { desc = 'Line diagnostics' })

-- =========================================
--  LazyVim 约定的 LSP 键位（在 LSP attach 时会被插件重写，这里放兜底）
-- =========================================
map('n', 'K', function()
  if has_coc() then
    vim.fn.CocActionAsync('doHover')
  elseif vim.lsp and vim.lsp.buf.hover then
    vim.lsp.buf.hover()
  else
    vim.api.nvim_feedkeys('K', 'n', false)
  end
end, { desc = 'Hover' })

map('n', 'gd', function()
  if has_coc() then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Plug>(coc-definition)', true, false, true), 'n', false)
  elseif vim.lsp and vim.lsp.buf.definition then
    vim.lsp.buf.definition()
  else
    vim.api.nvim_feedkeys('gd', 'n', false)
  end
end, { desc = 'Goto definition' })

map('n', 'gD', function()
  if has_coc() then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Plug>(coc-declaration)', true, false, true), 'n', false)
  elseif vim.lsp and vim.lsp.buf.declaration then
    vim.lsp.buf.declaration()
  else
    vim.api.nvim_feedkeys('gD', 'n', false)
  end
end, { desc = 'Goto declaration' })

map('n', 'gi', function()
  if has_coc() then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Plug>(coc-implementation)', true, false, true), 'n', false)
  elseif vim.lsp and vim.lsp.buf.implementation then
    vim.lsp.buf.implementation()
  else
    vim.api.nvim_feedkeys('gi', 'n', false)
  end
end, { desc = 'Goto implementation' })

map('n', 'gr', function()
  if has_coc() then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Plug>(coc-references)', true, false, true), 'n', false)
  elseif vim.lsp and vim.lsp.buf.references then
    vim.lsp.buf.references()
  else
    vim.api.nvim_feedkeys('gr', 'n', false)
  end
end, { desc = 'Goto references' })

map('n', '<leader>rn', function()
  if has_coc() then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Plug>(coc-rename)', true, false, true), 'n', false)
  elseif vim.lsp and vim.lsp.buf.rename then
    vim.lsp.buf.rename()
  end
end, { desc = 'Rename' })

map({ 'n', 'v' }, '<leader>ca', function()
  if has_coc() then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Plug>(coc-codeaction-selected)', true, false, true), 'n', false)
  elseif vim.lsp and vim.lsp.buf.code_action then
    vim.lsp.buf.code_action()
  end
end, { desc = 'Code action' })

-- =========================================
--  缓冲区 (LazyVim <leader>b 分组)
-- =========================================
map('n', '<leader>bb', '<cmd>b#<cr>',        { desc = 'Switch to previous buffer' })
map('n', '<leader>bd', '<cmd>bdelete<cr>',   { desc = 'Delete buffer' })
map('n', '<leader>bD', '<cmd>bdelete!<cr>',  { desc = 'Delete buffer (!)' })
map('n', '<leader>bn', '<cmd>bnext<cr>',     { desc = 'Next buffer' })
map('n', '<leader>bp', '<cmd>bprev<cr>',     { desc = 'Prev buffer' })

-- =========================================
--  UI 切换 (LazyVim <leader>u 分组)
-- =========================================
map('n', '<leader>us', function()
  opt.spell = not opt.spell:get()
  Util.debug('spell: ' .. (opt.spell:get() and 'on' or 'off'))
end, { desc = 'Toggle spell check' })

map('n', '<leader>uw', function()
  opt.wrap = not opt.wrap:get()
end, { desc = 'Toggle word wrap' })

map('n', '<leader>un', function()
  opt.number = not opt.number:get()
  opt.relativenumber = opt.number:get()
end, { desc = 'Toggle line numbers' })

-- =========================================
--  更好的上下移动（LazyVim 约定：兼容 wrapped lines + 可视模式）
-- =========================================
map({ 'n', 'x' }, 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
map({ 'n', 'x' }, 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })

-- =========================================
--  更好的粘贴 / 缩进（Visual 模式下 < / > 保持选区）
-- =========================================
map('v', '<', '<gv')
map('v', '>', '>gv')
map('v', 'p', '"_dP') -- 粘贴覆盖选区不污染无名寄存器

-- =========================================
--  LazyVim: 命令行模式 %% 展开为当前缓冲区路径
-- =========================================
map('c', '%%', function()
  if vim.fn.getcmdtype() == ':' then
    return vim.fn.expand('%:h') .. '/'
  else
    return '%%'
  end
end, { expr = true, desc = 'Expand %% to file dir in command line' })

-- =========================================
--  格式化（LazyVim <leader>cf 约定：coc → nvim-lsp 降级）
-- =========================================
map({ 'n', 'v' }, '<leader>cf', function()
  if vim.fn.exists('*CocActionAsync') == 1 then
    vim.fn.CocActionAsync('format')
  elseif vim.lsp and vim.lsp.buf.format then
    vim.lsp.buf.format({ async = true })
  end
end, { desc = 'Format buffer' })
