-- ===================================
-- Neovim 编辑器增强插件
-- ===================================

return {
  -- 文件树
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    keys = { { "<leader>e", "<cmd>Neotree toggle<CR>", desc = "文件树" } },
    dependencies = "nvim-lua/plenary.nvim",
    config = function()
      require("neo-tree").setup({
        close_if_last_window = true,
        window = { width = 30 },
      })
    end,
  },

  -- 模糊搜索
  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.8",
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<CR>", desc = "文件搜索" },
      { "<leader>fg", "<cmd>Telescope live_grep<CR>", desc = "文本搜索" },
      { "<leader>fb", "<cmd>Telescope buffers<CR>", desc = "缓冲区" },
      { "<leader>fh", "<cmd>Telescope help_tags<CR>", desc = "帮助" },
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
        cond = function()
          return vim.fn.executable("make") == 1
        end,
      },
    },
    config = function()
      require("telescope").setup({
        defaults = {
          layout_strategy = "horizontal",
          layout_config = { prompt_position = "top" },
        },
      })
      pcall(require("telescope").load_extension, "fzf")
    end,
  },

  -- Git 集成
  { "tpope/vim-fugitive",  cmd = { "G", "Git", "Gdiffsplit" } },
  {
    "lewis6991/gitsigns.nvim",
    event = "BufReadPre",
    config = function()
      require("gitsigns").setup({
        signs = {
          add = { text = "+" },
          change = { text = "~" },
          delete = { text = "-" },
        },
      })
    end,
  },

  -- 注释
  {
    "numToStr/Comment.nvim",
    keys = { { "gc", mode = { "n", "v" } }, { "gb", mode = { "n", "v" } } },
    config = true,
  },

  -- 自动括号
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = true,
  },

  -- 环绕字符
  {
    "kylechui/nvim-surround",
    version = "*",
    event = "VeryLazy",
    config = true,
  },
}