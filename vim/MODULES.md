# Dotfiles Neovim 模块（LazyVim 风格叠加层）

## 概述

本模块（`vim/lua/`）是完全基于 **LazyVim 框架的模块化设计理念** 新建的 Neovim 配置层，
具备以下特性：

| 特性 | 实现 |
|------|------|
| **零破坏性** | 原有 Vimscript 配置 (`core/`, `plugins/plugins.vim`, `ftplugin/`, `platform/`) **完全不动**；本模块仅作为可选叠加层 |
| **可一键关闭** | 在 `~/.vimrc.local` 中 `let g:dotfiles_enable_lua_modules = 0` 即完全禁用，退回到纯 Vimscript 行为 |
| **Vim 安全** | 仅当 `has('nvim')` 为真时加载，Vim 用户启动不会报错 |
| **LazyVim 目录约定** | `config/` 分 options / keymaps / autocmds；`plugins/` 按关注点分 editor / ui / coding / lsp；`user/` 个人扩展不入库 |
| **LazyVim 映射分组** | `<leader>f` 查找 / `<leader>g` Git / `<leader>s` 窗口 / `<leader>b` 缓冲区 / `<leader>u` UI / `<leader><tab>` 标签页 |
| **可切换插件管理** | 默认继续用现有 `vim-plug`；显式设置 `g:dotfiles_use_lazy_nvim = 1` 可切到 `lazy.nvim`，plugins/*.lua 按 LazyVim 规范自动加载 |
| **LSP 双通道** | 默认 `coc.nvim`（与现有一致）；设置 `g:dotfiles_lsp_provider = 'nvim'` 可切到 `nvim-lspconfig + nvim-cmp` |
| **国内镜像一致** | lazy.nvim bootstrap、registry 等镜像策略与项目约定（NO_MIRROR 开关 + 多级降级）完全一致 |
| **容错加载** | 每个子模块 `safe_require`：单模块失败发一条 WARN notify，不阻塞启动（LazyVim 风格） |

## 目录结构

```
vim/
├── lua/
│   ├── dotfiles_modules/
│   │   ├── init.lua              # 模块入口（装配顺序）
│   │   ├── util.lua              # 工具库 (debug/map/autocmd/glob_lua)
│   │   ├── config/
│   │   │   ├── options.lua       # vim.opt 选项（LazyVim 风格）
│   │   │   ├── keymaps.lua       # vim.keymap.set 键位（LazyVim 分组规范）
│   │   │   └── autocmds.lua      # nvim_create_autocmd (LazyVim: LastPlace / BigFile / HighlightOnYank 等)
│   │   └── plugins/
│   │       ├── init.lua          # lazy.nvim bootstrap + setup（g:dotfiles_use_lazy_nvim 才启用）
│   │       ├── editor.lua        # 编辑器增强插件 spec
│   │       ├── ui.lua            # 主题 / 状态栏 / 图标 / FZF / NERDTree
│   │       ├── coding.lua        # Git 集成（fugitive / gitgutter）
│   │       └── lsp.lua           # coc.nvim (默认) / nvim-lspconfig (可选)
│   └── user/
│       ├── README.md
│       ├── init.example.lua
│       └── plugins/example.lua
└── .gitignore                     # 新增 user/ 与 lazy-lock.json
```

## 开关变量一览

在 `~/.vimrc.local` 中（加载顺序在 Lua 模块之前）可以设置以下变量：

| 变量 | 类型 | 默认 | 作用 |
|------|------|------|------|
| `g:dotfiles_enable_lua_modules` | 0 / 1 | 1 (启用) | 整个 Lua 模块总开关，0 = 完全不加载 |
| `g:dotfiles_use_lazy_nvim` | 0 / 1 | 0 | 1 = 用 lazy.nvim 管理 plugins/*.lua 中声明的插件；0 = 继续使用 vim-plug（原有行为） |
| `g:dotfiles_lsp_provider` | `'coc'` / `'nvim'` | `'coc'` | `'nvim'` = 切到 `nvim-lspconfig + nvim-cmp + mason` |
| `g:dotfiles_bigfile_size` | 数字 (KB) | 1536 | BigFile autocmd 阈值（KB） |
| `g:dotfiles_modules_debug` | 0 / 1 | 0 | 1 = 打印模块 debug 级别 notify |
| `NO_MIRROR` | 环境变量 | 空 | 非空 = lazy.nvim / coc 安装时不走国内镜像 |

## 键位映射速查（LazyVim 分组规范）

| 组 | 前缀 | 常用映射 |
|----|------|----------|
| **Save/Quit** | 全局 | `<C-s>` 保存 · `<Esc>` 清 hlsearch |
| **Window** | `<leader>w` | `wv` 竖分 / `wh` 横分 / `we` 均分 / `wc` 关 / `wo` 留一 |
| **Tab** | `<leader><tab>` | `<tab>` 新建 / `n` 下一个 / `p` 上一个 / `c` 关 / `o` 留一 |
| **Buffer** | `<leader>b` | `bb` 上一个 / `bd` 删除 / `bn` 下一个 / `bp` 上一个 |
| **Diagnostics** | 全局 | `]d` 下一个 / `[d` 上一个 / `<leader>cd` 当前行浮窗 |
| **LSP** | 全局 | `gd` / `gD` / `gi` / `gr` / `K` 悬停 / `<leader>rn` 重命名 / `<leader>ca` 代码动作 / `<leader>cf` 格式化 |
| **UI** | `<leader>u` | `us` spell / `uw` wrap / `un` number |
| **FZF** | `<leader>f` | `ff` Files / `fg` GFiles / `fb` Buffers / `fs` Rg / `fl` Lines |
| **Git** | `<leader>g` | `gs` status / `gc` commit / `gb` blame / `gp` push / `gl` log |
| **Undotree** | `<leader>u` | 切换 |
| **NERDTree** | `<leader>e` / `n` | 切换；`E` 定位当前文件 |

更多映射细节见 [config/keymaps.lua](lua/dotfiles_modules/config/keymaps.lua)。

## 如何切换到 lazy.nvim 插件管理

1. 在 `~/.vimrc.local` 中：

   ```vim
   let g:dotfiles_use_lazy_nvim = 1
   ```

2. 重启 Neovim。若 `~/.local/share/nvim/lazy/lazy.nvim` 不存在会自动 bootstrap 安装（官方 → ghfast.top → ghproxy 镜像降级）。

3. 首次启动按 `:Lazy sync` 安装所有 spec 中声明的插件。

> 💡 **可以和 vim-plug 共存**：vim-plug 在 plugins.vim 中先加载，lazy.nvim 作为额外一层。
> 若想彻底切换，可在 `~/.vimrc.local` 中手动 `finish` 跳过 `plugins/plugins.vim` 的 source，再启用 lazy。

## 如何切换到 nvim-lspconfig（放弃 coc.nvim）

1. 在 `~/.vimrc.local` 中：

   ```vim
   let g:dotfiles_lsp_provider = 'nvim'
   let g:dotfiles_use_lazy_nvim  = 1   " nvim lsp 需要 mason.nvim，必须启用 lazy
   ```

2. 重启 Neovim，mason 会自动尝试拉取 `lua_ls / pyright / rust_analyzer / tsserver / ...`。

## 开发说明

- **新增插件**：按关注点放到 `plugins/<topic>.lua`，return `@type LazySpec[]`；LazyVim 会按文件自动 import。
- **新增选项/映射/自动命令**：放到 `config/*.lua`，由 `init.lua` 顺序加载。
- **模块间相互调用**：`require('dotfiles_modules.util')` 里的 `Util.map / Util.autocmd / Util.debug`。
- **校验语法**：`luac -p lua/dotfiles_modules/**/*.lua`（或 `nvim --headless -c 'lua require("dotfiles_modules")'`）。
- **变更原则**：不要修改 Vimscript 层（`core/*.vim`、`plugins/plugins.vim`）——它们是 Vim 9 兼容的基础层；
  Neovim 专属增强请放在 Lua 模块里。

## 故障排查

| 症状 | 排查 |
|------|------|
| Neovim 启动报错 `module 'dotfiles_modules' not found` | 检查 [vim/.vimrc](.vimrc) 末尾是否添加了 `runtimepath` 注入段。重新执行 `./vim/install.sh`。 |
| Lua 模块里的键位不生效 | 检查 `~/.vimrc.local` 中是否误设了 `g:dotfiles_enable_lua_modules = 0`。 |
| `E117: Unknown function: plug#begin` | vim-plug 未安装到 Neovim 路径。Neovim 使用 `~/.local/share/nvim/site/autoload/`（不同于 Vim 的 `~/.vim/autoload/`）。重新执行 `./vim/install.sh`，或手动: `curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim` |
| `Conflicting configs` 启动报错 | `~/.config/nvim/` 下同时存在 `init.lua` 和 `init.vim`。删除 `init.lua`（或改名 `.bak`），只保留 `init.vim`。 |
| lazy.nvim 尝试 clone `LazyVim/LazyVim` 失败 | `~/.config/nvim/` 下残留了旧 LazyVim 框架的 `lua/config/lazy.lua`。删除 `~/.config/nvim/lua/` 目录和 `init.lua`。 |
| lazy.nvim 始终 bootstrap 失败 | 设置 `NO_MIRROR=1 nvim` 强制走官方直连；或手动执行 git clone。 |
| coc 扩展不装 | 清掉 `~/.cache/vim/.coc_extensions_installed` 和 `~/.cache/vim/.coc_extensions_installed_lua` 再重启。 |
