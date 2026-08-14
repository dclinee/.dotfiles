-- ===================================
-- Neovim 配置入口
-- ===================================
-- 加载顺序: 基础配置 → 插件 → 键位 → AI → 平台
-- 插件管理: lazy.nvim（自动安装，国内镜像优先）

-- 防止重复加载
if vim.g.dotfiles_nvim_loaded then
  return
end
vim.g.dotfiles_nvim_loaded = true

-- ===================================
-- 基础配置
-- ===================================
local opt = vim.opt

-- 基础
opt.encoding = "utf-8"
opt.fileencoding = "utf-8"
opt.number = true           -- 行号
opt.relativenumber = true   -- 相对行号
opt.mouse = "a"             -- 鼠标
opt.cmdheight = 2           -- 命令行高度
opt.termguicolors = true    -- 真彩色

-- 缩进
opt.tabstop = 4
opt.softtabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.smartindent = true

-- 搜索
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

-- 滚动
opt.scrolloff = 8
opt.sidescrolloff = 8

-- 自动保存
opt.autowrite = true
opt.undofile = true

-- 缓存目录
local cache_dir = vim.fn.expand("~/.cache/nvim")
vim.fn.mkdir(cache_dir .. "/undo", "p")
vim.fn.mkdir(cache_dir .. "/backup", "p")
vim.fn.mkdir(cache_dir .. "/swap", "p")
opt.undodir = cache_dir .. "/undo"
opt.backupdir = cache_dir .. "/backup"
opt.directory = cache_dir .. "/swap"

-- 快捷键
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- ===================================
-- 插件管理器: lazy.nvim 自动安装
-- ===================================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  local out = vim.fn.system({
    "git", "clone",
    "--filter=blob:none",
    "https://ghfast.top/https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
  -- 镜像失败则直连 GitHub
  if vim.v.shell_error ~= 0 then
    vim.fn.system({
      "git", "clone",
      "--filter=blob:none",
      "https://github.com/folke/lazy.nvim.git",
      "--branch=stable",
      lazypath,
    })
  end
end
vim.opt.rtp:prepend(lazypath)

-- ===================================
-- 加载插件
-- ===================================
require("lazy").setup({
  spec = {
    -- 导入插件模块
    { import = "plugins.ai" },
    { import = "plugins.editor" },
    { import = "plugins.lsp" },
    { import = "plugins.ui" },
  },
  defaults = {
    lazy = true,         -- 默认懒加载
    version = false,     -- 始终使用最新版
  },
  install = {
    colorscheme = { "tokyonight" },
    -- 国内镜像: 安装失败时自动尝试
    missing = true,
  },
  checker = {
    enabled = true,      -- 自动检查更新
    notify = false,      -- 不弹通知
  },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "matchit",
        "matchparen",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})