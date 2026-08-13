--[[
  plugins/editor.lua
  LazyVim 风格插件 spec: 编辑器增强

  每个 spec 返回 LazySpec list（LazyVim 约定）。
  所有插件同时与 `plugins/plugins.vim` 中 vim-plug 清单保持一致，
  只是通过 lazy.nvim 声明（当用户启用 g:dotfiles_use_lazy_nvim 时生效）。
]]

--- @type LazySpec[]
return {

  -- Surround 环绕字符操作（cs/ds/ys）
  {
    'tpope/vim-surround',
    event = { 'BufReadPost', 'BufNewFile' },
  },

  -- 自动括号匹配
  {
    'jiangmiao/auto-pairs',
    event = 'InsertEnter',
    config = function()
      -- LazyVim 风格：关闭对 ' 的智能匹配（英文太常用）
      vim.g.AutoPairsMapCh = 0
    end,
  },

  -- 多光标编辑（LazyVim: <C-n> 触发）
  {
    'terryma/vim-multiple-cursors',
    keys = {
      { '<C-n>', '<Plug>(multiple_cursors_start)', desc = 'MC start' },
    },
    init = function()
      vim.g.multi_cursor_use_default_mapping = 0
    end,
  },

  -- 撤销树可视化
  {
    'mbbill/undotree',
    cmd = 'UndotreeToggle',
    keys = {
      { '<leader>u', '<cmd>UndotreeToggle<cr>', desc = 'Toggle undo tree' },
    },
    config = function()
      vim.g.undotree_WindowLayout = 2
      vim.g.undotree_SetFocusWhenToggle = 1
    end,
  },

  -- 注释插件 (NERD Commenter)
  {
    'preservim/nerdcommenter',
    event = { 'BufReadPost', 'BufNewFile' },
    keys = {
      { '<leader>cc', desc = 'NERD comment', mode = { 'n', 'v' } },
      { '<leader>cu', desc = 'NERD uncomment', mode = { 'n', 'v' } },
    },
    init = function()
      vim.g.NERDSpaceDelims = 1
      vim.g.NERDDefaultAlign = 'left'
      vim.g.NERDCommentEmptyLines = 1
      vim.g.NERDTrimTrailingWhitespace = 1
    end,
  },

  -- 文件类型语法高亮合集 (LazyVim 相当于 treesitter 之前的基础保障)
  {
    'sheerun/vim-polyglot',
    version = false,
    event = { 'BufReadPre', 'BufNewFile' },
    init = function()
      -- polyglot 自带 indent 覆盖可能破坏现有设置，禁用
      vim.g.polyglot_disabled = { 'autoindent', 'ftdetect' }
    end,
  },

  -- 代码片段引擎（与 coc.nvim / vim-vsnip-integ 配合）
  {
    'hrsh7th/vim-vsnip',
    event = 'InsertEnter',
    keys = {
      { '<c-j>',
        function()
          if vim.fn['vsnip#available'](1) == 1 then return '<Plug>(vsnip-expand-or-jump)' end
          return '<c-j>'
        end,
        expr = true, mode = { 'i', 's' }, desc = 'VSnip expand/jump' },
    },
  },
  {
    'hrsh7th/vim-vsnip-integ',
    event = 'InsertEnter',
    after = 'vim-vsnip',
  },

  -- Treesitter (Neovim 0.9+ 推荐，LazyVim 默认的语法高亮基础设施)
  -- 仅 Neovim 提供；Vim 下由 vim-polyglot 接管
  {
    'nvim-treesitter/nvim-treesitter',
    cond = function() return vim.fn.has('nvim-0.9') == 1 end,
    version = false,
    event = { 'BufReadPost', 'BufNewFile' },
    build = ':TSUpdate',
    dependencies = {
      { 'nvim-treesitter/nvim-treesitter-textobjects' },
      { 'nvim-treesitter/nvim-treesitter-context' },
    },
    config = function()
      require('nvim-treesitter.configs').setup({
        ensure_installed = 'all',
        sync_install = false,
        auto_install = true,
        highlight = {
          enable = true,
          -- 保留 coc + polyglot 的旧语法高亮作为兜底
          additional_vim_regex_highlighting = false,
        },
        indent = { enable = true },
        incremental_selection = {
          enable = true,
          keymaps = {
            init_selection = '<CR>',
            node_incremental = '<CR>',
            scope_incremental = false,
            node_decremental = '<BS>',
          },
        },
      })
    end,
  },
}
