--[[
  plugins/coding.lua
  LazyVim 风格插件 spec: 编码辅助 / Git / 调试 / 格式化
]]

--- @type LazySpec[]
return {

  -- ========== Git 集成 ==========
  -- vim-fugitive (LazyVim <leader>g 分组)
  {
    'tpope/vim-fugitive',
    cmd = { 'G', 'Git', 'Gdiffsplit', 'Gread', 'Gwrite', 'Gblame', 'Gcommit', 'Gpush', 'Glog' },
    keys = {
      { '<leader>gs', '<cmd>G<cr>',        desc = 'Git status' },
      { '<leader>gc', '<cmd>G commit<cr>', desc = 'Git commit' },
      { '<leader>gb', '<cmd>G blame<cr>',  desc = 'Git blame' },
      { '<leader>gp', '<cmd>G push<cr>',   desc = 'Git push' },
      { '<leader>gl', '<cmd>G log<cr>',    desc = 'Git log' },
      { '<leader>gd', '<cmd>Gdiffsplit<cr>', desc = 'Git diff split' },
    },
  },

  -- vim-gitgutter（行级 Git 状态）
  {
    'airblade/vim-gitgutter',
    event = { 'BufReadPost', 'BufNewFile' },
    init = function()
      vim.g.gitgutter_sign_added = '+'
      vim.g.gitgutter_sign_modified = '~'
      vim.g.gitgutter_sign_removed = '-'
      vim.g.gitgutter_map_keys = 0       -- 不抢默认 [c / ]c 映射
      -- LazyVim 风格导航: [h / ]h 跳到上/下一个 hunk
      vim.api.nvim_set_keymap('n', ']h', [[<Plug>(GitGutterNextHunk)]],
        { silent = true, desc = 'Next Git hunk' })
      vim.api.nvim_set_keymap('n', '[h', [[<Plug>(GitGutterPrevHunk)]],
        { silent = true, desc = 'Prev Git hunk' })
    end,
  },
}
