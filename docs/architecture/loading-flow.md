# 配置加载流程

## Zsh 启动流程

```
.zshenv (所有 shell)
  └─▶ 设置 PATH、DOTFILES_ROOT、语言环境
       │
       ▼
.zshrc (交互式 shell)
  └─▶ 01. 加载 lib/output.sh + lib/symlink.sh
       02. 加载 core/00_env.zsh     (环境变量)
       03. 加载 core/01_options.zsh (Zsh 选项)
       04. 加载 core/02_aliases.zsh (别名定义)
       05. 加载 core/03_functions.zsh (函数定义)
       06. 加载 core/04_plugins.zsh (zinit 插件)
       07. 加载 core/05_starship.zsh (提示符)
       08. 加载 platform/{linux,macos}.zsh (平台配置)
```

## WezTerm 启动流程

```
wezterm.lua
  └─▶ 01. pcall 保护加载
       02. 加载 core/00_basic.lua    (基础配置)
       03. 加载 core/01_keybindings.lua (快捷键)
       04. 加载 core/02_colors.lua   (配色)
       05. 加载 core/03_events.lua   (事件)
       06. 加载 core/04_domains.lua  (域名)
       07. 加载 platform/{linux,macos,windows}.lua (平台)
```

## 加载顺序设计原则

1. **编号前缀**：`00_` → `01_` → `02_`...，按编号排序保证加载顺序
2. **平台隔离**：`platform/{linux,macos}.zsh` 在所有核心模块之后加载
3. **本地覆盖**：`~/.zshrc.local` 最后加载，覆盖仓库默认配置
4. **错误保护**：WezTerm 用 `pcall` 包裹加载，单个模块失败不影响整体

## 调试加载流程

```bash
# Zsh 启动调试
ZSH_DEBUG_PLUGINS=1 zsh   # 显示插件加载日志
~/.dotfiles/zsh/profile_performance.sh  # 启动性能测试

# 临时禁用插件（排查问题）
ZSH_DISABLE_PLUGINS=1 zsh

# 详细模式
zsh -x -c 'source ~/.zshrc'
```
