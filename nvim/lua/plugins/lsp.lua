-- ===================================
-- Neovim LSP / 补全 / 语法插件
-- ===================================

return {
  -- LSP 配置管理
  {
    "williamboman/mason.nvim",
    cmd = "Mason",
    build = ":MasonUpdate",
    config = function()
      require("mason").setup({
        ui = {
          border = "rounded",
          icons = {
            package_installed = "✓",
            package_pending = "→",
            package_uninstalled = "✗",
          },
        },
      })
    end,
  },

  -- LSP 安装桥接
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = "williamboman/mason.nvim",
    config = function()
      require("mason-lspconfig").setup({
        -- 自动安装语言服务器
        automatic_installation = true,
        ensure_installed = {
          "lua_ls",
          "pyright",
          "rust_analyzer",
          "gopls",
          "tsserver",
          "jsonls",
          "yamlls",
          "bashls",
          "dockerls",
          "terraformls",
        },
      })
    end,
  },

  -- LSP 客户端
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason-lspconfig.nvim",
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      local lsp = require("lspconfig")
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      -- 通用 on_attach
      local on_attach = function(_, bufnr)
        local map = function(keys, func, desc)
          vim.keymap.set("n", keys, func, { buffer = bufnr, desc = desc })
        end
        map("gd", vim.lsp.buf.definition, "跳转到定义")
        map("gr", vim.lsp.buf.references, "查看引用")
        map("K", vim.lsp.buf.hover, "悬停信息")
        map("<leader>rn", vim.lsp.buf.rename, "重命名")
        map("<leader>ca", vim.lsp.buf.code_action, "代码操作")
        map("<leader>f", function() vim.lsp.buf.format({ async = true }) end, "格式化")
      end

      -- 自动配置已知服务器
      local servers = { "lua_ls", "pyright", "rust_analyzer", "gopls", "tsserver", "jsonls", "yamlls", "bashls", "dockerls", "terraformls" }
      for _, server in ipairs(servers) do
        lsp[server].setup({
          capabilities = capabilities,
          on_attach = on_attach,
        })
      end
    end,
  },

  -- 自动补全引擎
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      cmp.setup({
        snippet = {
          expand = function(args) luasnip.lsp_expand(args.body) end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<Tab>"] = cmp.mapping.select_next_item(),
          ["<S-Tab>"] = cmp.mapping.select_prev_item(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<C-Space>"] = cmp.mapping.complete(),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "buffer" },
          { name = "path" },
        }),
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
      })
    end,
  },

  -- 代码片段
  {
    "L3MON4D3/LuaSnip",
    config = function()
      require("luasnip.loaders.from_vscode").lazy_load()
    end,
  },

  -- Treesitter 语法高亮
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = "BufReadPost",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = { "lua", "python", "rust", "go", "javascript", "typescript", "bash", "yaml", "toml", "json", "dockerfile", "hcl", "markdown", "markdown_inline" },
        auto_install = true,
        highlight = { enable = true },
        indent = { enable = true },
      })
    end,
  },
}