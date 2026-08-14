--[[
  Dotfiles Neovim 模块 — 基础选项 config/options.lua
  遵循 LazyVim vim.opt 命名规范；所有设置均为追加/补充，
  不覆盖 Vimscript core/00_basic.vim 中已配置的值。

  启用条件: has('nvim') + g:dotfiles_enable_lua_modules != 0
]]

local opt = vim.opt

-- =========================================
--  性能/兼容性（Neovim 独有的安全默认值）
-- =========================================
opt.shortmess:append('c')           -- 补全消息简写（LazyVim 默认）
opt.shortmess:append('W')           -- 不写 "written" 提示
opt.shortmess:append('I')           -- 禁用启动画面 intro
opt.shortmess:append('C')           -- 不显示扫描 ins-completion 消息
opt.joinspaces = false              -- 两空格 join 行为

-- 编辑器行为（Neovim 专属增强，不与 Vimscript 的 set 冲突）
opt.splitkeep = 'screen'            -- 水平分割时保持屏幕行对齐 (nvim-0.9+)
opt.splitbelow = true               -- 水平分屏默认向下
opt.splitright = true               -- 垂直分屏默认向右
opt.timeoutlen = 300                -- 映射等待时间（LazyVim 300ms 默认）
opt.updatetime = 200                -- CursorHold 触发间隔（coc/补全响应更快）

-- 撤销/备份（Neovim 使用不同的默认缓存路径，更规范）
local cache = vim.fn.stdpath('cache')
opt.undodir:prepend(cache .. '/undo')
opt.backupdir:prepend(cache .. '/backup')
opt.directory:prepend(cache .. '/swap')

-- 确认存在，避免首启报错
for _, d in ipairs({ cache .. '/undo', cache .. '/backup', cache .. '/swap' }) do
  vim.fn.mkdir(d, 'p')
end

-- 真彩色/符号（Neovim 叠加层再次确认 termguicolors；与 Vimscript core + platform 分层设置保持幂等）
if vim.fn.has('termguicolors') == 1 then
  opt.termguicolors = true
end

-- =========================================
--  LazyVim 默认视觉
-- =========================================
opt.cursorline = true               -- 光标行高亮 (LazyVim 默认 on)
opt.conceallevel = 2                -- 隐藏语法糖字符（LazyVim 默认）
opt.pumblend = 10                   -- 浮窗轻微透明（LazyVim 风格）
opt.winblend = 10                   -- 浮窗透明度
opt.signcolumn = 'yes'              -- 始终保留 sign 列（诊断不抖动）
opt.numberwidth = 2                 -- 行号列最小宽

-- 搜索（已有 ignorecase/smartcase，这里仅追加 Neovim 风格）
opt.inccommand = 'nosplit'          -- 替换命令实时预览（LazyVim 默认）

-- 缩进（LazyVim 4空格默认；ftplugin 会针对具体语言覆盖）
opt.shiftround = true               -- 缩进对齐到整数倍 shiftwidth

-- =========================================
--  Folds (nvim-0.9+ LSP foldmethod)
--  保守：若 Vimscript 已设 nofoldenable 则不强制
-- =========================================
if vim.fn.has('nvim-0.9') == 1 and opt.foldenable:get() then
  opt.foldlevel = 99
  opt.foldlevelstart = 99
  opt.foldenable = true
end

-- =========================================
--  诊断样式（LazyVim 风格，coc/nvim-lsp 都会用）
-- =========================================
if vim.diagnostic and vim.diagnostic.config then
  local signs = {
    { name = 'DiagnosticSignError', text = '' },
    { name = 'DiagnosticSignWarn',  text = '' },
    { name = 'DiagnosticSignHint',  text = '' },
    { name = 'DiagnosticSignInfo',  text = '󰋼' },
  }
  for _, s in ipairs(signs) do
    vim.fn.sign_define(s.name, { texthl = s.name, text = s.text, numhl = '' })
  end
  vim.diagnostic.config({
    virtual_text = { spacing = 4, prefix = '●' }, -- LazyVim 默认样式
    underline = true,
    update_in_insert = false,
    severity_sort = true,
    float = { border = 'rounded', source = 'if_many' },
  })
end
