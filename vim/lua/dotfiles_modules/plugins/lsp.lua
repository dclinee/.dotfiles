--[[
  plugins/lsp.lua
  LazyVim 风格插件 spec: LSP / 补全 / 诊断

  项目默认使用 coc.nvim（与现有 Vimscript 一致），
  这里同时提供 nvim-lspconfig + nvim-cmp 的可选路径作为参考，
  不启用，除非用户显式设置 g:dotfiles_lsp_provider = 'nvim'。
]]

local use_nvim_lsp = vim.g.dotfiles_lsp_provider == 'nvim'

--- @type LazySpec[]
return {

  -- ========== coc.nvim（默认路径，与 vim-plug 清单一致）==========
  {
    'neoclide/coc.nvim',
    branch = 'release',
    cond = not use_nvim_lsp,
    event = { 'BufReadPost', 'BufNewFile' },
    -- release 分支已是预构建版本，无需 npm install
    init = function()
      -- 声明扩展列表（与 plugins/plugins.vim L100 保持同步）
      local exts = {
        'coc-json', 'coc-pyright', 'coc-java', 'coc-html', 'coc-css',
        'coc-tsserver', 'coc-vimlsp', 'coc-go', 'coc-rust-analyzer',
        'coc-snippets', 'coc-markdownlint', 'coc-prettier', 'coc-yaml',
        'coc-toml', 'coc-sh', 'coc-docker', 'coc-terraform',
        'coc-lua', 'coc-spell-checker',
      }
      vim.g.coc_global_extensions = exts

      -- 在首次启动时异步触发 CocInstall（与 Vimscript 一致的幂等逻辑）
      local flag = vim.fn.expand('~/.cache/vim/.coc_extensions_installed_lua')
      if vim.fn.filereadable(flag) == 0 and vim.fn.exists(':CocInstall') == 2 then
        vim.api.nvim_create_autocmd('User', {
          pattern = 'CocNvimInit',
          once = true,
          callback = function()
            local missing = {}
            for _, e in ipairs(exts) do
              local d = vim.fn.expand('~/.config/coc/extensions/node_modules/' .. e)
              if vim.fn.isdirectory(d) == 0 then
                table.insert(missing, e)
              end
            end
            if #missing > 0 then
              vim.notify('[dotfiles] installing coc: ' .. table.concat(missing, ' '))
              vim.cmd('CocInstall ' .. table.concat(missing, ' '))
            end
            vim.fn.writefile({ 'done' }, flag)
          end,
        })
      end

      -- Coc 浮窗样式（LazyVim 圆角边框）
      vim.g.coc_floating_style = { border = 'rounded', max_width = 80, max_height = 0.4 }
    end,
  },

  -- ========== nvim-lspconfig + nvim-cmp（可选路径，不默认启用）==========
  -- 当用户在 ~/.vimrc.local 中设置 let g:dotfiles_lsp_provider = 'nvim' 时启用
  {
    'neovim/nvim-lspconfig',
    cond = use_nvim_lsp,
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = {
      { 'williamboman/mason-lspconfig.nvim' },
      { 'williamboman/mason.nvim', config = true },
      { 'hrsh7th/nvim-cmp' },
      { 'hrsh7th/cmp-nvim-lsp' },
      { 'hrsh7th/cmp-buffer' },
      { 'hrsh7th/cmp-path' },
      { 'L3MON4D3/LuaSnip' },
    },
    config = function()
      local lspconfig = require('lspconfig')
      local capabilities = require('cmp_nvim_lsp').default_capabilities()
      -- 与 coc 扩展列表保持近似一致的语言服务器
      local servers = { 'lua_ls', 'pyright', 'gopls', 'rust_analyzer', 'tsserver', 'jsonls', 'yamlls' }
      for _, s in ipairs(servers) do
        lspconfig[s].setup({ capabilities = capabilities })
      end

      -- cmp + luasnip 基础 config
      local cmp = require('cmp')
      cmp.setup({
        snippet = { expand = function(args) require('luasnip').lsp_expand(args.body) end },
        mapping = cmp.mapping.preset.insert({
          ['<Tab>']   = cmp.mapping(function(fb) if cmp.visible() then cmp.select_next_item() else fb() end end, { 'i', 's' }),
          ['<S-Tab>'] = cmp.mapping(function(fb) if cmp.visible() then cmp.select_prev_item() else fb() end end, { 'i', 's' }),
          ['<CR>']    = cmp.mapping.confirm({ select = true }),
        }),
        sources = cmp.config.sources({
          { name = 'nvim_lsp' }, { name = 'luasnip' },
        }, {
          { name = 'buffer' }, { name = 'path' },
        }),
      })
    end,
  },
}
