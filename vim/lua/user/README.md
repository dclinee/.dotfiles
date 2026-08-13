# user/ — 用户自定义目录

本目录下除 `*.example` 文件外，**不会被 git 追踪**（见 `vim/.gitignore`）。
用于放置你自己的个性化扩展，不受仓库更新覆盖影响。

## 目录结构

```
vim/lua/user/
├── init.lua              # 你的自定义入口（可选，从 init.example.lua 复制后按需改）
├── init.example.lua      # 示例文件（保留在仓库作为参考）
└── plugins/
    ├── example.lua       # LazyVim 风格插件 spec 示例
    └── <your-name>.lua   # 你自己的插件 spec（不入库）
```

## 启用方式

1. 复制示例：

   ```bash
   cp ~/.dotfiles/vim/lua/user/init.example.lua ~/.dotfiles/vim/lua/user/init.lua
   ```

2. 编辑 `init.lua` 追加你的选项/映射/autocmd。

3. 自定义插件 spec：在 `plugins/` 下新建任意 `*.lua`，返回 LazySpec list：

   ```lua
   -- plugins/xxx.lua
   return {
     { 'some/plugin.nvim',
       keys = { { '<leader>xx', '<cmd>SomeCmd<cr>', desc = 'XXX' } },
     },
   }
   ```

## 加载顺序

```
core/0*.vim
  → plugins/plugins.vim (vim-plug)
    → lua/dotfiles_modules: options → autocmds → keymaps → (lazy.nvim+plugins)
      → lua/user.init    ← 你在这里，最后执行，可以覆盖一切
```
