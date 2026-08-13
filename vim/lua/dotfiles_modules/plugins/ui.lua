--[[
  plugins/ui.lua
  LazyVim 风格插件 spec: UI / 主题 / 状态栏 / 图标
]]

--- @type LazySpec[]
return {

  -- ========== 主题 ==========
  -- Tokyo Night（LazyVim 默认风格配色）
  {
    'folke/tokyonight.nvim',
    lazy = not (vim.g.colors_name == nil),
    priority = 1000,       -- 主题最先加载（LazyVim 约定）
    config = function()
      require('tokyonight').setup({
        style = 'night',
        transparent = true,
        styles = {
          comments = { italic = true },
          keywords = { italic = true },
          functions = { italic = true },
          sidebars = 'transparent',
          floats = 'transparent',
        },
      })
      -- 仅当 Vimscript 未明确加载主题时才设默认
      if not vim.g.colors_name then
        vim.cmd.colorscheme('tokyonight')
      end
    end,
  },

  -- Gruvbox（兜底/备选主题，与 Vimscript 一致）
  {
    'ellisonleao/gruvbox.nvim',
    lazy = true,
    priority = 999,
    config = function()
      require('gruvbox').setup({
        transparent_mode = true,
        italic = {
          strings = true,
          comments = true,
          keywords = true,
          folds = true,
        },
      })
    end,
  },

  -- ========== 状态栏 ==========
  -- vim-airline（与现有 Vimscript 配置一致）
  {
    'vim-airline/vim-airline',
    event = 'UIEnter',
    dependencies = { 'vim-airline/vim-airline-themes' },
    init = function()
      vim.g.airline_powerline_fonts = 1
      vim.g.airline_theme = 'tokyonight'
      vim.g['airline#extensions#tabline#enabled'] = 1
      vim.g['airline#extensions#tabline#fnamemod'] = ':t'
      -- 与 LazyVim lualine 风格一致的 sections
      vim.g.airline_section_b = '%{getcwd()}'
    end,
  },

  -- ========== 图标与文件浏览器 ==========
  -- 开发图标（所有 UI 插件的前置）
  {
    'nvim-tree/nvim-web-devicons',
    lazy = true,
    cond = function() return vim.fn.has('nvim') == 1 end,
    config = function()
      require('nvim-web-devicons').setup({ default = true })
    end,
  },

  -- vim-devicons（Vim/Neovim 都可用，airline/nerdtree 的图标依赖）
  {
    'ryanoasis/vim-devicons',
    event = 'UIEnter',
  },

  -- NERDTree 及其增强（LazyVim 等效是 nvim-tree.lua，这里保持与现有配置一致）
  {
    'preservim/nerdtree',
    cmd = { 'NERDTreeToggle', 'NERDTreeFocus', 'NERDTreeFind' },
    keys = {
      { '<leader>e', '<cmd>NERDTreeToggle<cr>', desc = 'Toggle NERDTree' },
      { '<leader>n', '<cmd>NERDTreeToggle<cr>', desc = 'Toggle NERDTree (alt)' },
      { '<leader>E', '<cmd>NERDTreeFind<cr>',   desc = 'Find in NERDTree' },
    },
    dependencies = {
      'Xuyuanp/nerdtree-git-plugin',
      'tiagofumo/vim-nerdtree-syntax-highlight',
    },
    init = function()
      vim.g.NERDTreeShowHidden = 1
      vim.g.NERDTreeIgnore = { '.git', 'node_modules', '.cache', '.venv', '__pycache__' }
      vim.g.NERDTreeShowLineNumbers = 1
      vim.g.NERDTreeAutoDeleteBuffer = 1
    end,
  },

  -- Tagbar（符号导航）
  {
    'preservim/tagbar',
    cmd = 'TagbarToggle',
    keys = { { '<leader>t', '<cmd>TagbarToggle<cr>', desc = 'Toggle Tagbar' } },
    init = function()
      vim.g.tagbar_autoclose = 1
      vim.g.tagbar_width = 30
    end,
  },

  -- FZF (LazyVim 等效是 telescope.nvim，这里保持与现有配置一致)
  {
    'junegunn/fzf',
    build = function() vim.fn['fzf#install']() end,
    lazy = true,
  },
  {
    'junegunn/fzf.vim',
    cmd = { 'Files', 'GFiles', 'Buffers', 'Rg', 'Lines', 'Tags' },
    keys = {
      { '<leader>ff', '<cmd>Files<cr>',   desc = 'FZF Files' },
      { '<leader>fg', '<cmd>GFiles<cr>',  desc = 'FZF Git Files' },
      { '<leader>fb', '<cmd>Buffers<cr>', desc = 'FZF Buffers' },
      { '<leader>fs', '<cmd>Rg<cr>',      desc = 'FZF Grep (Rg)' },
      { '<leader>fl', '<cmd>Lines<cr>',   desc = 'FZF Lines' },
    },
    config = function()
      -- 与 LazyVim Telescope 视觉一致：浮动 + 透明 + 圆角边框
      vim.g.fzf_layout = {
        window = {
          width = 0.85,
          height = 0.75,
          border = 'rounded',
          xoffset = 0.5,
          yoffset = 0.5,
        },
      }
      vim.g.fzf_colors = {
        fg = { 'fg', 'Normal' },
        bg = { 'bg', 'NormalFloat' },
        border = { 'fg', 'FloatBorder' },
        hl = { 'fg', 'Comment' },
        ['fg+'] = { 'fg', 'CursorLine' },
        ['bg+'] = { 'bg', 'CursorLine' },
        ['hl+'] = { 'fg', 'Statement' },
        info = { 'fg', 'PreProc' },
        prompt = { 'fg', 'Conditional' },
        pointer = { 'fg', 'Exception' },
        marker = { 'fg', 'Keyword' },
        spinner = { 'fg', 'Label' },
        header = { 'fg', 'Comment' },
      }
    end,
  },
}
