--[[
  plugins/ui.lua
  LazyVim 风格插件 spec: UI / 主题 / 状态栏 / 图标 / Which-Key

  Spacemacs 分层：<leader> 下所有映射由 which-key 注册分组名，
  避免在 core/01_keybindings.vim / config/keymaps.lua 间重复描述。
]]

local Util = require('dotfiles_modules.util')

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

  -- ========== Which-Key：Spacemacs 风格分组提示 ==========
  -- 默认通过 vim-plug 安装 + init.lua 直接加载 config/which-key.lua
  -- 仅在启用 lazy.nvim 时由 lazy 管理懒加载（cond 控制）
  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    cond = vim.g.dotfiles_use_lazy_nvim == 1,
    config = function(_, opts)
      require('dotfiles_modules.config.which-key').setup(opts)
    end,
  },

  -- ========== 状态栏 ==========
  {
    'vim-airline/vim-airline',
    event = 'UIEnter',
    dependencies = { 'vim-airline/vim-airline-themes' },
    init = function()
      vim.g.airline_powerline_fonts = 1
      vim.g.airline_theme = 'tokyonight'
      vim.g['airline#extensions#tabline#enabled'] = 1
      vim.g['airline#extensions#tabline#fnamemod'] = ':t'
      vim.g.airline_section_b = '%{getcwd()}'
    end,
  },

  -- ========== 图标与文件浏览器 ==========
  {
    'nvim-tree/nvim-web-devicons',
    lazy = true,
    cond = function() return vim.fn.has('nvim') == 1 end,
    config = function()
      require('nvim-web-devicons').setup({ default = true })
    end,
  },

  { 'ryanoasis/vim-devicons', event = 'UIEnter' },

  -- NERDTree 及其增强
  {
    'preservim/nerdtree',
    cmd = { 'NERDTreeToggle', 'NERDTreeFocus', 'NERDTreeFind' },
    -- 注意：<leader>e / <leader>n / <leader>E 与 Spacemacs 分组无冲突（e=Edit / n=Narrow 下已未占用）
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
    -- 注：Spacemacs 下 T = Tabs；Tagbar 独立命令，保持原入口
    keys = { { '<leader>oT', '<cmd>TagbarToggle<cr>', desc = 'Toggle Tagbar (outline)' } },
    init = function()
      vim.g.tagbar_autoclose = 1
      vim.g.tagbar_width = 30
    end,
  },

  -- ========== FZF + Telescope 双通道 ==========
  -- 优先使用 Telescope（如果已安装）；FZF 仅作为兜底。
  -- 所有键位在 config/keymaps.lua 中声明为 Telescope；FZF 不在此处声明 keys，
  -- 以免与 Spacemacs 分层中的 <leader>f / <leader>p / <leader>s 描述重复。
  {
    'junegunn/fzf',
    build = function() vim.fn['fzf#install']() end,
    lazy = true,
  },
  {
    'junegunn/fzf.vim',
    cmd = { 'Files', 'GFiles', 'Buffers', 'Rg', 'Lines', 'Tags' },
    config = function()
      vim.g.fzf_layout = {
        window = { width = 0.85, height = 0.75, border = 'rounded', xoffset = 0.5, yoffset = 0.5 },
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

  -- Telescope（优先，未装则由 config/keymaps.lua 中的映射触发 FZF 命令 fallback）
  {
    'nvim-telescope/telescope.nvim',
    version = '*',
    cmd = 'Telescope',
    dependencies = {
      'nvim-lua/plenary.nvim',
      {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = Util.on_mac() and 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build'
          or 'make',
      },
    },
    config = function()
      local t = require('telescope')
      t.setup({
        defaults = {
          prompt_prefix = '❯ ',
          selection_caret = '❯ ',
          entry_prefix = '  ',
          winblend = 0,
          layout_strategy = 'horizontal',
          layout_config = {
            width = 0.9, height = 0.85, preview_cutoff = 120,
            horizontal = { preview_width = 0.6 },
          },
          mappings = {
            i = {
              ['<C-j>'] = 'move_selection_next',
              ['<C-k>'] = 'move_selection_previous',
              ['<C-q>'] = 'send_to_qflist',
            },
            n = { ['q'] = 'close' },
          },
          file_ignore_patterns = { '.git/', 'node_modules/', '__pycache__/', '%.o$', '%.a$' },
          vimgrep_arguments = {
            'rg', '--color=never', '--no-heading', '--with-filename',
            '--line-number', '--column', '--smart-case', '--hidden',
            '-g', '!.git/', '-g', '!node_modules/',
          },
        },
      })
      pcall(t.load_extension, 'fzf')
    end,
  },
  { 'nvim-lua/plenary.nvim', lazy = true },
}
