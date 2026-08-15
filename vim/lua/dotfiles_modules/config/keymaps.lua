--[[
  Dotfiles Neovim 模块 — 全局键位映射 config/keymaps.lua
  完全遵循 Spacemacs 助记分层 + Which-Key 友好：
    顶级分组：
      a=Apps   b=Buffers  c=Code    d=Dotfiles  e=Edit     f=Files
      g=Git+Goto          h=Help    j=Jump      k=Kustom   m=Major(,)
      n=Narrow p=Project  P=Plug    q=Quit      r=Reg      s=Search
      t=Toggle T=Tabs     v=VBlock  w=Windows   x=eXtras   y=Yank    z=Fold
    同时保留 4 周双写兼容（受 vim.g.dotfiles_spacemacs_compat 控制），
    与 Vimscript core/01_keybindings.vim 同步，关闭后即为纯 Spacemacs。
]]

local Util = require('dotfiles_modules.util')
local map  = Util.map
local opt  = vim.opt

local compat = (vim.g.dotfiles_spacemacs_compat == nil) and true or (vim.g.dotfiles_spacemacs_compat ~= 0)

-- =========================================
--  0. 基础：保存 / 退出 / 清搜索
-- =========================================
-- 通用保存：插入/可视/普通模式都能 Ctrl+S
map({ 'i', 'v', 'n', 's' }, '<C-s>', '<cmd>w<cr><esc>', { desc = 'Save file' })
-- Escape 清除 hlsearch（同时 Esc 本身行为不变）
map('n', '<Esc>', '<cmd>nohls<cr><esc>', { desc = 'Escape and clear hlsearch' })

-- Q 组：退出
map('n', '<leader>qq', '<cmd>qa<cr>',       { desc = 'Quit all' })
map('n', '<leader>qQ', '<cmd>qa!<cr>',      { desc = 'Quit all (!)' })
map('n', '<leader>qw', '<cmd>wq<cr>',       { desc = 'Save & quit window' })
map('n', '<leader>qW', '<cmd>wqa<cr>',      { desc = 'Save & quit all' })
map('n', '<leader>qx', '<cmd>x<cr>',        { desc = 'Save (if changed) & quit' })
map('n', '<leader>q!', '<cmd>q!<cr>',       { desc = 'Quit window (!)' })
if compat then
  map('n', '<leader>q',  '<cmd>q<cr>',      { desc = '[compat] Quit window' })
  map('n', '<leader>wq', '<cmd>wq<cr>',     { desc = '[compat] Save & quit' })
  map('n', '<leader>qa', '<cmd>qa<cr>',     { desc = '[compat] Quit all' })
  map('n', '<leader>Q',  '<cmd>qa!<cr>',    { desc = '[compat] Quit all (!)' })
end

-- =========================================
--  1. 文件（<leader>f 组）
-- =========================================
map('n', '<leader>ff', Util.telescope_or('find_files',                  'Files',   'find '),  { desc = 'Find file' })
map('n', '<leader>fF', "<cmd>e <cfile><cr>",                            { desc = 'Open file under cursor' })
map('n', '<leader>fr', Util.telescope_or('oldfiles',                    'History', 'browse oldfiles'), { desc = 'Recent files' })
map('n', '<leader>fs', '<cmd>w<cr>',                                    { desc = 'Save file' })
map('n', '<leader>fS', '<cmd>wa<cr>',                                   { desc = 'Save all files' })
map('n', '<leader>fe', "<cmd>e $MYVIMRC<cr>",                           { desc = 'Edit .vimrc' })
map('n', '<leader>fE', '<cmd>source $MYVIMRC<cr>',                      { desc = 'Reload .vimrc' })
map('n', '<leader>fl', '<cmd>lcd %:p:h<cr><cmd>pwd<cr>',                { desc = 'lcd to file dir (window-local)' })
map('n', '<leader>fL', '<cmd>cd  %:p:h<cr><cmd>pwd<cr>',                { desc = 'cd to file dir (global)' })
map('n', '<leader>fo', '<cmd>NERDTreeFind<cr>',                         { desc = 'Reveal in NERDTree' })
map('n', '<leader>fy', function() vim.fn.setreg('+', vim.fn.expand('%:p')) end,    { desc = 'Yank abs path' })
map('n', '<leader>fY', function() vim.fn.setreg('+', vim.fn.expand('%:~:.')) end,   { desc = 'Yank rel path' })
map('n', '<leader>fD', function()
  local f = vim.api.nvim_buf_get_name(0)
  vim.cmd('bdelete')
  vim.fn.delete(f)
end, { desc = 'Delete file & buffer' })
if compat then
  map('n', '<leader>w',  '<cmd>w<cr>', { desc = '[compat] Save file' })
end

-- =========================================
--  2. 窗口（<leader>w 组）—— 与 Vimscript 保持一致
-- =========================================
map('n', '<leader>wv', '<C-w>v', { desc = 'Split vertically' })
map('n', '<leader>wh', '<C-w>s', { desc = 'Split horizontally' })
map('n', '<leader>wc', '<C-w>c', { desc = 'Close window' })
map('n', '<leader>wo', '<C-w>o', { desc = 'Close other windows' })
map('n', '<leader>we', '<C-w>=', { desc = 'Equalize splits' })
map('n', '<leader>w=', '<C-w>=', { desc = 'Equalize splits' })
map('n', '<leader>ws', '<C-w>x', { desc = 'Swap with next' })
map('n', '<leader>wH', '<C-w>H', { desc = 'Move window left' })
map('n', '<leader>wJ', '<C-w>J', { desc = 'Move window down' })
map('n', '<leader>wK', '<C-w>K', { desc = 'Move window up' })
map('n', '<leader>wL', '<C-w>L', { desc = 'Move window right' })
-- 方向键移动（normal 模式已在上方 Vimscript 用 nnoremap 处理；此处补 i/t 两模式）
map({ 'i', 't' }, '<C-h>', [[<Cmd>wincmd h<CR>]], { desc = 'Go to left window' })
map({ 'i', 't' }, '<C-j>', [[<Cmd>wincmd j<CR>]], { desc = 'Go to lower window' })
map({ 'i', 't' }, '<C-k>', [[<Cmd>wincmd k<CR>]], { desc = 'Go to upper window' })
map({ 'i', 't' }, '<C-l>', [[<Cmd>wincmd l<CR>]], { desc = 'Go to right window' })
-- 调整尺寸
map('n', '<C-Up>',    '<cmd>resize +2<cr>',          { desc = 'Increase window height' })
map('n', '<C-Down>',  '<cmd>resize -2<cr>',          { desc = 'Decrease window height' })
map('n', '<C-Left>',  '<cmd>vertical resize -2<cr>', { desc = 'Decrease window width' })
map('n', '<C-Right>', '<cmd>vertical resize +2<cr>', { desc = 'Increase window width' })
if compat then
  map('n', '<leader>sv', '<C-w>v', { desc = '[compat] Split vertically' })
  map('n', '<leader>sh', '<C-w>s', { desc = '[compat] Split horizontally' })
  map('n', '<leader>sc', '<C-w>c', { desc = '[compat] Close window' })
  map('n', '<leader>so', '<C-w>o', { desc = '[compat] Close other windows' })
end

-- =========================================
--  3. 缓冲区（<leader>b 组）
-- =========================================
map('n', '<leader>bb', '<cmd>b#<cr>',                    { desc = 'Previous buffer' })
map('n', '<leader>bd', '<cmd>bdelete<cr>',               { desc = 'Delete buffer' })
map('n', '<leader>bD', '<cmd>bdelete!<cr>',              { desc = 'Delete buffer (!)' })
map('n', '<leader>bn', '<cmd>bnext<cr>',                 { desc = 'Next buffer' })
map('n', '<leader>bp', '<cmd>bprev<cr>',                 { desc = 'Prev buffer' })
map('n', '<leader>bl', '<cmd>ls<cr>',                    { desc = 'List buffers' })
map('n', '<leader>b`', Util.telescope_or('buffers', 'Buffers', 'ls'), { desc = 'List buffers' })

-- =========================================
--  4. 标签页（<leader>T 组 + <leader><tab> 别名）
-- =========================================
map('n', '<leader>Tn',         '<cmd>tabnew<cr>',     { desc = 'New tab' })
map('n', '<leader>Tc',         '<cmd>tabclose<cr>',   { desc = 'Close tab' })
map('n', '<leader>To',         '<cmd>tabonly<cr>',    { desc = 'Close other tabs' })
map('n', '<leader>Tl',         '<cmd>tabnext<cr>',    { desc = 'Next tab' })
map('n', '<leader>Th',         '<cmd>tabprevious<cr>',{ desc = 'Prev tab' })
map('n', '<leader><tab><tab>', '<cmd>tabnew<cr>',     { desc = 'New tab' })
map('n', '<leader><tab>n',     '<cmd>tabnext<cr>',    { desc = 'Next tab' })
map('n', '<leader><tab>p',     '<cmd>tabprevious<cr>',{ desc = 'Prev tab' })
map('n', '<leader><tab>c',     '<cmd>tabclose<cr>',   { desc = 'Close tab' })
map('n', '<leader><tab>o',     '<cmd>tabonly<cr>',    { desc = 'Close other tabs' })
map('n', '<S-l>',              '<cmd>tabnext<cr>',    { desc = 'Next tab' })
map('n', '<S-h>',              '<cmd>tabprevious<cr>',{ desc = 'Prev tab' })
if compat then
  map('n', '<leader>tn', '<cmd>tabnew<cr>',     { desc = '[compat] New tab' })
  map('n', '<leader>tc', '<cmd>tabclose<cr>',   { desc = '[compat] Close tab' })
  map('n', '<leader>to', '<cmd>tabonly<cr>',    { desc = '[compat] Close other tabs' })
  map('n', '<leader>tl', '<cmd>tabnext<cr>',    { desc = '[compat] Next tab' })
  map('n', '<leader>th', '<cmd>tabprevious<cr>',{ desc = '[compat] Prev tab' })
end

-- =========================================
--  5. 跳转（<leader>j 组）
-- =========================================
map('n', '<leader>jj', '8j',          { desc = 'Jump 8 lines down' })
map('n', '<leader>jk', '8k',          { desc = 'Jump 8 lines up' })
map('n', '<leader>jh', '^',           { desc = 'Jump to line start' })
map('n', '<leader>jl', '$',           { desc = 'Jump to line end' })
map('n', '<leader>jJ', '}',           { desc = 'Jump paragraph down' })
map('n', '<leader>jK', '{',           { desc = 'Jump paragraph up' })
map('n', '<leader>jm', Util.telescope_or('marks',       'Marks',  'marks'),   { desc = 'Jump to mark' })
map('n', '<leader>jo', Util.telescope_or('jumplist',    'Jumps',  'jumps'),   { desc = 'Jump list' })
map('n', '<leader>jc', Util.telescope_or('commands',    'Commands', 'command '), { desc = 'Jump to command' })
map('n', '<leader>jb', Util.telescope_or('buffers',     'Buffers', 'ls<CR>:b '), { desc = 'Jump to buffer' })
map('n', '<leader>jf', Util.telescope_or('file_browser','Files',  'find '),   { desc = 'Jump to folder' })
if compat then
  map('n', '<leader>j', '8j', { desc = '[compat] Jump 8 lines down' })
  map('n', '<leader>k', '8k', { desc = '[compat] Jump 8 lines up' })
  map('n', '<leader>h', '^',  { desc = '[compat] Jump to line start' })
  map('n', '<leader>l', '$',  { desc = '[compat] Jump to line end' })
end

-- =========================================
--  6. 搜索（<leader>s 组）
-- =========================================
map('n', '<leader>sb', Util.telescope_or('current_buffer_fuzzy_find', 'Lines',    ''),        { desc = 'Search in buffer' })
map('n', '<leader>sg', Util.telescope_or('live_grep',                   'Rg',       ''),        { desc = 'Search project (grep)' })
map('n', '<leader>s/', Util.telescope_or('live_grep',                   'Rg',       ''),        { desc = 'Search project (grep)' })
map('n', '<leader>s*', Util.telescope_or('grep_string',                 'Rg <C-r><C-w>', ''),  { desc = 'Search word under cursor' })
map('n', '<leader>sr', '<cmd>lua require("telescope").extensions and pcall(require("telescope.builtin").resume) and vim.cmd.Telescope resume or vim.cmd.echohl WarningMsg \\| echom "no previous search to resume" \\| echohl None<cr>',
                                                                                               { desc = 'Resume last search' })
map('n', '<leader>sc', '<cmd>nohls<cr>',                               { desc = 'Clear hlsearch' })
map('n', '<leader>sn', '<cmd>nohls<cr>',                               { desc = 'Clear hlsearch (alias)' })
map('n', '<leader>sS', ':%s//gc<Left><Left><Left>',                    { desc = 'Substitute (%%s//gc)' })
map('n', '<leader>sm', Util.telescope_or('marks', 'Marks', 'marks'),    { desc = 'Search marks' })
map('n', '<leader>sj', Util.telescope_or('jumplist', 'Jumps', 'jumps'), { desc = 'Search jumplist' })
if compat then
  map('n', '<leader>/', '<cmd>nohls<cr>', { desc = '[compat] Clear hlsearch' })
end

-- =========================================
--  7. 编辑（<leader>e 组）
-- =========================================
map({ 'n', 'v' }, '<leader>ea', 'ggVG',                       { desc = 'Select all' })
map('n',          '<leader>ei', 'gg=G',                       { desc = 'Indent whole buffer' })
map('n',          '<leader>ed', [[:%s/\s\+$//e<CR>]],         { desc = 'Delete trailing spaces' })
map('n',          '<leader>es', '[s1z=',                      { desc = 'Fix 1st spell error' })
map('n',          '<leader>eS', 'z=',                         { desc = 'Spell suggest' })
map('n',          '<leader>eU', 'gUU',                        { desc = 'Uppercase line' })
map('n',          '<leader>eu', 'guu',                        { desc = 'Lowercase line' })
map('n',          '<leader>e<', '<G',                         { desc = 'Dedent buffer' })
map('n',          '<leader>e>', '>G',                         { desc = 'Indent buffer' })
-- 移动行（Alt+j/k）
map('n',          '<A-j>', ':m .+1<CR>==',                    { desc = 'Move line down' })
map('n',          '<A-k>', ':m .-2<CR>==',                    { desc = 'Move line up' })
map('v',          '<A-j>', ":m '>+1<CR>gv=gv",                { desc = 'Move line down' })
map('v',          '<A-k>', ":m '<-2<CR>gv=gv",                { desc = 'Move line up' })
if compat then
  map({ 'n', 'v' }, '<leader>a', 'ggVG', { desc = '[compat] Select all' })
end

-- =========================================
--  8. 切换（<leader>t 组） — 替换原 <leader>u 组
-- =========================================
map('n', '<leader>tn', function()
  opt.number         = not opt.number:get()
  opt.relativenumber = opt.number:get()
end, { desc = 'Toggle line numbers' })
map('n', '<leader>ts', function() opt.spell = not opt.spell:get() end,  { desc = 'Toggle spell' })
map('n', '<leader>tw', function() opt.wrap  = not opt.wrap:get()  end,  { desc = 'Toggle word wrap' })
map('n', '<leader>th', function() opt.hlsearch = not opt.hlsearch:get() end, { desc = 'Toggle hlsearch' })
map('n', '<leader>ti', function() opt.ignorecase = not opt.ignorecase:get() end, { desc = 'Toggle ignorecase' })
map('n', '<leader>tp', function() opt.paste = not opt.paste:get() end,  { desc = 'Toggle paste' })
map('n', '<leader>tz', function() opt.foldenable = not opt.foldenable:get() end, { desc = 'Toggle fold' })
if compat then
  map('n', '<leader>us', function() opt.spell = not opt.spell:get() end, { desc = '[compat] Toggle spell' })
  map('n', '<leader>uw', function() opt.wrap  = not opt.wrap:get()  end, { desc = '[compat] Toggle wrap' })
  map('n', '<leader>un', function()
    opt.number         = not opt.number:get()
    opt.relativenumber = opt.number:get()
  end, { desc = '[compat] Toggle line numbers' })
end

-- =========================================
--  9. 剪贴板（<leader>y 组）— 系统剪贴板
-- =========================================
map({ 'n', 'v' }, '<leader>ys', [["+y]],        { desc = 'Yank motion/selection to system' })
map('n',          '<leader>yS', [[gg"+yG]],     { desc = 'Yank whole buffer to system' })
map('n',          '<leader>yy', [["+yy]],       { desc = 'Yank line to system' })
map('n',          '<leader>yY', [["+Y]],        { desc = 'Yank to end of line (system)' })
map('n',          '<leader>y0', [["+y0]],       { desc = 'Yank to start of line (system)' })
map('n',          '<leader>y$', [["+y$]],       { desc = 'Yank to end of line (system)' })
map({ 'n', 'v' }, '<leader>yp', [["+p]],        { desc = 'Paste from system (after)' })
map('n',          '<leader>yP', [["+P]],        { desc = 'Paste from system (before)' })
if compat then
  map({ 'n', 'v' }, '<leader>y', [["+y]],  { desc = '[compat] Yank to system' })
  map('n',          '<leader>Y', [["+Y]],  { desc = '[compat] Yank line-end to system' })
  map({ 'n', 'v' }, '<leader>p', [["+p]],  { desc = '[compat] Paste from system' })
end

-- =========================================
--  10. 项目（<leader>p 组） — 原小写 p 不再是粘贴
-- =========================================
map('n', '<leader>pf', Util.telescope_or('git_files',  'GFiles',  'find '),   { desc = 'Project: find file (git scoped)' })
map('n', '<leader>pF', Util.telescope_or('find_files', 'Files',   'find '),   { desc = 'Project: find file (all)' })
map('n', '<leader>pb', Util.telescope_or('buffers',    'Buffers', 'ls<CR>:b '),{ desc = 'Project: buffers' })
map('n', '<leader>pr', Util.telescope_or('oldfiles',   'History', 'browse oldfiles'), { desc = 'Project: recent files' })
map('n', '<leader>p/', Util.telescope_or('live_grep',  'Rg',      ''),        { desc = 'Project: grep' })
map('n', '<leader>pt', '<cmd>NERDTreeToggle<cr>',                            { desc = 'Project: toggle tree' })

-- =========================================
--  11. 插件管理（<leader>P 大写 = Plugins）— vim-plug 与 lazy.nvim 双通道
-- =========================================
local function lazy_or(plug_cmd)
  return function()
    if pcall(require, 'lazy') then
      vim.cmd.Lazy(plug_cmd)
    elseif vim.fn.exists(':Plug' .. plug_cmd:sub(1,1):upper() .. plug_cmd:sub(2)) == 2 then
      vim.cmd('Plug' .. plug_cmd:sub(1,1):upper() .. plug_cmd:sub(2))
    else
      vim.notify('No plugin manager available (lazy/vim-plug)', vim.log.levels.WARN)
    end
  end
end
map('n', '<leader>Pi', lazy_or('install'), { desc = 'Plugins: install' })
map('n', '<leader>Pu', lazy_or('update'),  { desc = 'Plugins: update' })
map('n', '<leader>Pc', lazy_or('clean'),   { desc = 'Plugins: clean' })
map('n', '<leader>Ps', lazy_or('home'),    { desc = 'Plugins: status/home' })
map('n', '<leader>Px', lazy_or('upgrade'), { desc = 'Plugins: upgrade manager' })
if compat then
  map('n', '<leader>pi', lazy_or('install'), { desc = '[compat] Plugins install' })
  map('n', '<leader>pu', lazy_or('update'),  { desc = '[compat] Plugins update' })
  map('n', '<leader>pc', lazy_or('clean'),   { desc = '[compat] Plugins clean' })
  map('n', '<leader>ps', lazy_or('home'),    { desc = '[compat] Plugins status' })
end

-- =========================================
--  Coc / nvim-lsp 运行时探测（按键时判断）
-- =========================================
local function has_coc() return vim.fn.exists('*CocActionAsync') == 1 end

-- Code 组：<leader>c —— 诊断、格式化、重命名、code action
map('n', ']d', function()
  if has_coc() then vim.fn['CocActionAsync']('diagnosticNext')
  elseif vim.diagnostic then vim.diagnostic.goto_next() end
end, { desc = 'Next diagnostic' })
map('n', '[d', function()
  if has_coc() then vim.fn['CocActionAsync']('diagnosticPrev')
  elseif vim.diagnostic then vim.diagnostic.goto_prev() end
end, { desc = 'Prev diagnostic' })
map('n', '<leader>cd', function()
  if has_coc() then vim.fn.CocActionAsync('diagnosticList')
  elseif vim.diagnostic then vim.diagnostic.open_float() end
end, { desc = 'Line diagnostics' })
map({ 'n', 'v' }, '<leader>cf', function()
  if vim.fn.exists('*CocActionAsync') == 1 then vim.fn.CocActionAsync('format')
  elseif vim.lsp and vim.lsp.buf.format then vim.lsp.buf.format({ async = true }) end
end, { desc = 'Format buffer' })
map('n', '<leader>cr', function()
  if has_coc() then vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Plug>(coc-rename)', true, false, true), 'n', false)
  elseif vim.lsp and vim.lsp.buf.rename then vim.lsp.buf.rename() end
end, { desc = 'Rename (LSP)' })
map({ 'n', 'v' }, '<leader>ca', function()
  if has_coc() then vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Plug>(coc-codeaction-selected)', true, false, true), 'n', false)
  elseif vim.lsp and vim.lsp.buf.code_action then vim.lsp.buf.code_action() end
end, { desc = 'Code action' })
-- <leader>c] / c[ 作为 [d/]d 的别名
map('n', '<leader>c]', function()
  if has_coc() then vim.fn['CocActionAsync']('diagnosticNext')
  elseif vim.diagnostic then vim.diagnostic.goto_next() end
end, { desc = 'Next diagnostic' })
map('n', '<leader>c[', function()
  if has_coc() then vim.fn['CocActionAsync']('diagnosticPrev')
  elseif vim.diagnostic then vim.diagnostic.goto_prev() end
end, { desc = 'Prev diagnostic' })
if compat then
  map('n', '<leader>rn', function()
    if has_coc() then vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Plug>(coc-rename)', true, false, true), 'n', false)
    elseif vim.lsp and vim.lsp.buf.rename then vim.lsp.buf.rename() end
  end, { desc = '[compat] Rename' })
  map('n', '<leader>]', function()
    if has_coc() then vim.fn['CocActionAsync']('diagnosticNext')
    elseif vim.diagnostic then vim.diagnostic.goto_next() end
  end, { desc = '[compat] Next diagnostic' })
  map('n', '<leader>[', function()
    if has_coc() then vim.fn['CocActionAsync']('diagnosticPrev')
    elseif vim.diagnostic then vim.diagnostic.goto_prev() end
  end, { desc = '[compat] Prev diagnostic' })
end

-- G 组：Goto（LSP gd/gD/gi/gr 共享 <leader>g 前缀）
map('n', 'K', function()
  if has_coc() then vim.fn.CocActionAsync('doHover')
  elseif vim.lsp and vim.lsp.buf.hover then vim.lsp.buf.hover()
  else vim.api.nvim_feedkeys('K', 'n', false) end
end, { desc = 'Hover' })
map('n', '<leader>gd', function()
  if has_coc() then vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Plug>(coc-definition)', true, false, true), 'n', false)
  elseif vim.lsp and vim.lsp.buf.definition then vim.lsp.buf.definition()
  else vim.api.nvim_feedkeys('gd', 'n', false) end
end, { desc = 'Goto definition' })
map('n', '<leader>gD', function()
  if has_coc() then vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Plug>(coc-declaration)', true, false, true), 'n', false)
  elseif vim.lsp and vim.lsp.buf.declaration then vim.lsp.buf.declaration()
  else vim.api.nvim_feedkeys('gD', 'n', false) end
end, { desc = 'Goto declaration' })
map('n', '<leader>gi', function()
  if has_coc() then vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Plug>(coc-implementation)', true, false, true), 'n', false)
  elseif vim.lsp and vim.lsp.buf.implementation then vim.lsp.buf.implementation()
  else vim.api.nvim_feedkeys('gi', 'n', false) end
end, { desc = 'Goto implementation' })
map('n', '<leader>gt', function()
  if has_coc() then vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Plug>(coc-type-definition)', true, false, true), 'n', false)
  elseif vim.lsp and vim.lsp.buf.type_definition then vim.lsp.buf.type_definition() end
end, { desc = 'Goto type definition' })
map('n', '<leader>gr', function()
  if has_coc() then vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Plug>(coc-references)', true, false, true), 'n', false)
  elseif vim.lsp and vim.lsp.buf.references then vim.lsp.buf.references()
  else vim.api.nvim_feedkeys('gr', 'n', false) end
end, { desc = 'Goto references' })

-- Git（<leader>g 与 Goto 共前缀，子域分岔：gD/d/i/r/t 为 Goto；其他为 Git）
map('n', '<leader>gs', function() if pcall(require, 'neogit') then vim.cmd.Neogit() else vim.cmd.Git() end end, { desc = 'Git status' })
map('n', '<leader>gb', '<cmd>Git blame<cr>',       { desc = 'Git blame' })
map('n', '<leader>gl', '<cmd>Git log --oneline --decorate --graph -20<cr>', { desc = 'Git log (graph)' })
map('n', '<leader>gh', function() vim.cmd.GitGutterLineHighlightsToggle() end, { desc = 'Git gutter highlight toggle' })

-- =========================================
--  更好的上下移动（wrapped lines 友好）+ 可视化选区粘/缩进
-- =========================================
map({ 'n', 'x' }, 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
map({ 'n', 'x' }, 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
map('v', '<', '<gv')
map('v', '>', '>gv')
map('v', 'p', '"_dP')  -- 粘贴覆盖选区不污染无名寄存器

-- =========================================
--  LazyVim：命令行 %% 展开为当前缓冲区目录
-- =========================================
map('c', '%%', function()
  if vim.fn.getcmdtype() == ':' then return vim.fn.expand('%:h') .. '/' else return '%%' end
end, { expr = true, desc = 'Expand %% to file dir' })
