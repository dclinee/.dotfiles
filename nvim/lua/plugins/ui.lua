-- ===================================
-- Neovim UI 插件
-- ===================================

return {
  -- 主题
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("tokyonight").setup({
        style = "night",
        transparent = true,
        styles = {
          comments = { italic = true },
          keywords = { italic = true },
          functions = { italic = true },
          variables = { italic = true },
        },
      })
      vim.cmd("colorscheme tokyonight")
    end,
  },

  -- 状态栏
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    config = function()
      require("lualine").setup({
        options = {
          theme = "tokyonight",
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },
        },
      })
    end,
  },

  -- 顶部标签栏
  {
    "akinsho/bufferline.nvim",
    event = "VeryLazy",
    config = function()
      require("bufferline").setup({
        options = {
          mode = "buffers",
          separator_style = "thin",
        },
      })
    end,
  },

  -- 缩进线
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = "VeryLazy",
    config = function()
      require("ibl").setup({
        scope = { enabled = false },
      })
    end,
  },

  -- 启动页
  {
    "goolord/alpha-nvim",
    event = "VimEnter",
    config = function()
      local alpha = require("alpha")
      local dashboard = require("alpha.themes.dashboard")
      dashboard.section.header.val = {
        "",
        "",
        "",
        " ╻ ╻┏━╸┏━┓╻┏┳┓",
        " ┃┏┛┣╸ ┃ ┃┃┃┃┃",
        " ┗┛ ┗━╸┗━┛╹╹ ╹",
        "",
        "",
      }
      dashboard.section.buttons.val = {
        dashboard.button("f", "  Find file", ":Telescope find_files <CR>"),
        dashboard.button("r", "  Recent files", ":Telescope oldfiles <CR>"),
        dashboard.button("s", "  Restore session", ":SessionManager load_last_session<CR>"),
        dashboard.button("c", "  Config", ":e ~/.config/nvim/init.lua<CR>"),
        dashboard.button("q", "  Quit", ":qa<CR>"),
      }
      alpha.setup(dashboard.opts)
    end,
  },

  -- 通知美化
  {
    "rcarriga/nvim-notify",
    event = "VeryLazy",
    config = function()
      require("notify").setup({
        background_colour = "#000000",
        timeout = 3000,
      })
      vim.notify = require("notify")
    end,
  },
}