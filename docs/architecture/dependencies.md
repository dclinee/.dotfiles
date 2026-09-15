# 模块依赖关系

## 依赖树

```
bootstrap.sh
    │
    ├──▶ EditorConfig (无依赖)
    ├──▶ Git (无依赖)
    ├──▶ Brew (无依赖，提供 brew 命令)
    │
    ├──▶ Zsh (依赖 Brew: zinit, starship, eza, zoxide)
    │     ├── core/00_env.zsh    (环境变量)
    │     ├── core/01_options.zsh (Zsh 选项)
    │     ├── core/02_aliases.zsh (别名)
    │     ├── core/03_functions.zsh (函数)
    │     ├── core/04_plugins.zsh (zinit 插件)
    │     ├── core/05_starship.zsh (提示符)
    │     └── platform/{linux,macos}.zsh (平台配置)
    │
    ├──▶ Vim (依赖 Brew: vim)
    │     ├── core/00_basic.vim
    │     ├── core/01_keybindings.vim
    │     ├── plugins/plugins.vim
    │     ├── ftplugin/{python,javascript,go,rust,make}.vim
    │     └── platform/{linux,macos,windows}.vim
    │
    ├──▶ Emacs (依赖 Brew: emacs)
    │     ├── early-init.el
    │     ├── init.el
    │     └── lisp/init-*.el
    │
    ├──▶ WezTerm (依赖 Brew: wezterm)
    │     ├── wezterm.lua (入口)
    │     ├── core/00_basic.lua
    │     ├── core/01_keybindings.lua
    │     ├── core/02_colors.lua
    │     ├── core/03_events.lua
    │     ├── core/04_domains.lua
    │     └── platform/{linux,macos,windows}.lua
    │
    ├──▶ Python (依赖 Brew: python, uv)
    │     ├── install.sh
    │     ├── requirements.txt
    │     ├── requirements-web.txt
    │     ├── pip.conf
    │     └── pyproject.toml.template
    │
    ├──▶ Rust (依赖 Brew: rustup)
    │     ├── install.sh
    │     ├── cargo_config.toml.template
    │     ├── rustfmt.toml
    │     └── clippy.toml
    │
    └──▶ Tmux (依赖 Brew: tmux)
          └── .tmux.conf
```

## 共享库（lib/）

所有模块共享以下库，提供跨平台抽象：

| 库 | 用途 | 关键函数 |
|---|---|---|
| `lib/common.sh` | 通用函数 + 模块委托 | `check_init` / `check_ok` / `check_summary` / `read_tools_list` |
| `lib/output.sh` | Oh My Zsh 风格输出 | `echo_step` / `echo_success` / `echo_warn` / `echo_error` |
| `lib/symlink.sh` | 符号链接管理 | `safe_symlink`（源检查 + 备份 + 跨平台 resolve） |

`_common.sh` 模式：每个模块根目录放 `_common.sh`，做路径解析后 `source` lib/common.sh，再 `source` lib/output.sh 和 lib/symlink.sh。

## 相关 ADR

- [ADR-004: core/platform 分层](/decisions/adr-004)
- [ADR-005: safe_symlink 统一管理](/decisions/adr-005)
