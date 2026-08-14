--[[
  Dotfiles Neovim 模块 — 自动命令 config/autocmds.lua
  遵循 LazyVim 的 augroup 命名约定（"dotfiles_" 前缀）与 { clear = true } 风格

  启用条件: has('nvim') + g:dotfiles_enable_lua_modules != 0
]]

local Util = require('dotfiles_modules.util')
local autocmd = Util.autocmd

-- =========================================
--  1. 恢复上次打开的光标位置（LazyVim: LastPlace）
-- =========================================
autocmd('BufReadPost', {
  group = 'dotfiles_last_loc',
  callback = function()
    local exclude = { 'gitcommit', 'commit' }
    local buf = vim.api.nvim_get_current_buf()
    if vim.tbl_contains(exclude, vim.bo[buf].filetype) then
      return
    end
    local mark = vim.api.nvim_buf_get_mark(buf, '"')
    local lcount = vim.api.nvim_buf_line_count(buf)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- =========================================
--  2. 大文件模式：自动禁用 treesitter / 高亮 / 缩进（LazyVim: BigFile）
--     阈值默认 1.5 MB，可通过 g:dotfiles_bigfile_size 覆盖（单位：KB）
-- =========================================
local bigfile_size_kb = vim.g.dotfiles_bigfile_size or (1.5 * 1024)
autocmd({ 'BufReadPre', 'FileReadPre' }, {
  group = 'dotfiles_big_file',
  callback = function(args)
    local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(args.buf))
    if ok and stats and stats.size > bigfile_size_kb * 1024 then
      vim.cmd.syntax('clear')
      vim.cmd.filetype('off')
      -- 直接 pcall 执行命令，不存在的命令会静默失败；不做 require 判断（'treesitter' 不是合法模块名）
      pcall(vim.cmd, 'TSBufDisable highlight')
      pcall(vim.cmd, 'TSBufDisable indent')
      pcall(vim.cmd, 'TSBufDisable incremental_selection')
      vim.bo[args.buf].swapfile = false
      vim.opt_local.foldmethod = 'manual'
      Util.debug(string.format('bigfile mode on %s (%dKB)', vim.fn.fnamemodify(args.file, ':t'), stats.size / 1024))
    end
  end,
})

-- =========================================
--  3. 离开插入模式后自动保存（LazyVim 默认）+ 聚焦窗口保存
--    仅当 autowriteall 已开启（Vimscript core/00_basic.vim 有设置，这里兼容）
-- =========================================
if vim.o.autowriteall then
  autocmd({ 'BufLeave', 'FocusLost', 'InsertLeave' }, {
    group = 'dotfiles_auto_write',
    callback = function(args)
      if vim.bo[args.buf].buftype == '' and vim.bo[args.buf].modifiable then
        pcall(vim.cmd, 'silent! write')
      end
    end,
  })
end

-- =========================================
--  4. 进入终端模式自动进入 insert（LazyVim 默认）
-- =========================================
autocmd('TermOpen', {
  group = 'dotfiles_terminal',
  pattern = { '*' },
  callback = function()
    if not string.find(vim.bo.filetype or '', 'fugitive') then
      vim.cmd.startinsert()
    end
  end,
})

-- =========================================
--  5. yank 高亮（LazyVim 默认: HighlightOnYank）
-- =========================================
autocmd('TextYankPost', {
  group = 'dotfiles_highlight_yank',
  callback = function()
    pcall(vim.highlight.on_yank, { higroup = 'IncSearch', timeout = 200 })
  end,
})

-- =========================================
--  6. 调整窗口大小时自动平衡分屏（LazyVim 默认）
-- =========================================
autocmd({ 'VimResized' }, {
  group = 'dotfiles_resize',
  callback = function()
    vim.cmd.wincmd('=')
  end,
})

-- =========================================
--  7. Alpha/无文件打开时：禁用 statusline 装饰（LazyVim 风格）
--    轻量实现：当 buffer 为空 [No Name] 且 ft 为空时关闭 ruler
-- =========================================
autocmd('FileType', {
  group = 'dotfiles_alpha_ft',
  pattern = { 'alpha', 'dashboard', 'starter' },
  callback = function(args)
    vim.opt_local.laststatus = 0
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = 'no'
    -- 嵌套 autocmd 不传 group：避免再次 clear 同名 augroup 导致外层 FileType 被移除
    -- 已绑定 buffer=args.buf 为 buffer-local，生命周期由 buffer 管理即可
    autocmd('BufUnload', {
      buffer = args.buf,
      callback = function()
        vim.opt_local.laststatus = vim.go.laststatus
        vim.opt_local.number = vim.go.number
        vim.opt_local.relativenumber = vim.go.relativenumber
        vim.opt_local.signcolumn = vim.go.signcolumn
      end,
    })
  end,
})

-- =========================================
--  8. Quickfix/Location list 自动打开 + 自动跳转首条（与 :cope 一致的 UX）
--     非自动：除非明确触发才打开；仅自动美化
-- =========================================
autocmd('FileType', {
  group = 'dotfiles_qf',
  pattern = { 'qf' },
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = 'no'
  end,
})
