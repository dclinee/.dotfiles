--[[
  config/which-key.lua
  Spacemacs 风格 Which-Key 分组提示 — 独立于 lazy.nvim 的加载入口。
  - Neovim 默认：通过 vim-plug 安装 folke/which-key.nvim，由 init.lua 直接调用此模块
  - 若启用 lazy.nvim：plugins/ui.lua 的 spec config 也会调用此模块（幂等，不会重复 setup）
  - Vim（非 Neovim）：使用 liuchengxu/vim-which-key，在 plugins.vim 中独立配置
]]

local M = {}

local loaded = false

--- 默认 opts（与 plugins/ui.lua 的 lazy spec 保持同步）
local default_opts = {
  plugins = {
    marks = true,
    registers = true,
    spelling = { enabled = true, suggestions = 20 },
    presets = {
      operators = true,
      motions = true,
      text_objects = true,
      windows = true,
      nav = true,
      z = true,
      g = true,
    },
  },
  icons = {
    breadcrumb = '»',
    separator = '➜',
    group = '+',
  },
  popup_mappings = { scroll_down = '<C-d>', scroll_up = '<C-u>' },
  window = {
    border = 'rounded',
    position = 'bottom',
    winblend = 0,
  },
  layout = { height = { min = 4, max = 25 }, width = { min = 20, max = 50 }, spacing = 3 },
  ignore_missing = true,
  show_help = true,
}

--- Spacemacs 顶级分组（26 组）+ 二层子分组注册
local function register_groups(wk)
  -- 顶级分组
  wk.register({
    mode = { 'n', 'v' },
    ['<leader>'] = {
      a = { name = '+Applications' },
      b = { name = '+Buffers' },
      c = { name = '+Code (LSP/Diag/Fmt)' },
      d = { name = '+Dotfiles' },
      e = { name = '+Edit' },
      f = { name = '+Files' },
      g = { name = '+Git + Goto (LSP)' },
      h = { name = '+Help / Highlight' },
      j = { name = '+Jump' },
      k = { name = '+Kustom (User)' },
      m = { name = '+Major Mode (alias ,)' },
      n = { name = '+Narrow & UI' },
      p = { name = '+Project' },
      P = { name = '+Plugins (lazy / plug)' },
      q = { name = '+Quit & Session' },
      r = { name = '+Registers / Rings' },
      s = { name = '+Search' },
      t = { name = '+Toggles' },
      T = { name = '+Tabs' },
      v = { name = '+Visual & Block' },
      w = { name = '+Windows' },
      x = { name = '+eXtras / Text' },
      y = { name = '+Yank & Paste (System)' },
      z = { name = '+Fold' },
      ['<tab>'] = { name = '+Tabs' },
    },
  })

  -- 二层热门子分组
  wk.register({
    mode = { 'n', 'v' },
    ['<leader>c'] = {
      a = { name = 'Code action' },
      d = { name = 'Diagnostics' },
      f = { name = 'Format buffer' },
      r = { name = 'Rename symbol' },
    },
    ['<leader>g'] = {
      b = { name = 'Blame' },
      d = { name = 'Goto definition' },
      D = { name = 'Goto declaration' },
      h = { name = 'Gutter highlight toggle' },
      i = { name = 'Goto implementation' },
      l = { name = 'Log (graph)' },
      r = { name = 'Goto references' },
      s = { name = 'Status (Neogit/Git)' },
      t = { name = 'Goto type definition' },
    },
    ['<leader>f'] = {
      f = { name = 'Find file' },
      F = { name = 'File under cursor' },
      r = { name = 'Recent files' },
      s = { name = 'Save file' },
      S = { name = 'Save all' },
      e = { name = 'Edit dotfiles' },
      E = { name = 'Reload vimrc' },
      l = { name = 'lcd to file dir' },
      L = { name = 'cd to file dir' },
      o = { name = 'Reveal in NERDTree' },
      y = { name = 'Yank abs path' },
      Y = { name = 'Yank rel path' },
      D = { name = 'Delete file & buffer' },
    },
    ['<leader>w'] = {
      v = { name = 'Split vertical' },
      h = { name = 'Split horizontal' },
      c = { name = 'Close' },
      o = { name = 'Close others' },
      e = { name = 'Equal size' },
      ['='] = { name = 'Equal size' },
      s = { name = 'Swap with next' },
      H = { name = 'Move left' },
      J = { name = 'Move down' },
      K = { name = 'Move up' },
      L = { name = 'Move right' },
    },
  })
end

--- 初始化 which-key.nvim（幂等：多次调用安全）
---@param opts? table  可选自定义 opts，默认使用 default_opts
function M.setup(opts)
  if loaded then return end

  if vim.fn.has('nvim-0.9') ~= 1 then
    return -- which-key.nvim v3 需要 Neovim 0.9+
  end

  local ok, wk = pcall(require, 'which-key')
  if not ok then
    -- 插件未安装（vim-plug 尚未 PlugInstall），静默跳过
    return
  end

  wk.setup(opts or default_opts)
  register_groups(wk)
  loaded = true
end

return M
