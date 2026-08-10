# Dotfiles 架构文档

## 系统架构

```
┌─────────────────────────────────────────────────────────────┐
│                      bootstrap.sh                            │
│                   (主安装入口 + 依赖管理)                      │
│   顺序: EditorConfig → Git → Brew → Zsh → Vim → Emacs       │
│         → WezTerm → Python → Rust → Tmux                    │
├─────────────────────────────────────────────────────────────┤
│                        lib/                                  │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐   │
│  │ common.sh   │ │ output.sh   │ │ symlink.sh          │   │
│  │ (通用函数)   │ │ (输出美化)   │ │ (符号链接管理)       │   │
│  └──────┬──────┘ └──────┬──────┘ └──────────┬──────────┘   │
└─────────┼───────────────┼───────────────────┼──────────────┘
          │               │                   │
    ┌─────▼─────┐   ┌────▼─────┐   ┌─────────▼─────────┐
    │ 11 模块    │   │ Oh My    │   │ safe_symlink()     │
    │ install.sh │   │ Zsh 风格  │   │ - 源文件检查        │
    │            │   │ 输出函数  │   │ - 已存在跳过/备份   │
    └──────┬─────┘   └──────────┘   │ - 跨平台 resolve   │
           │                        └────────────────────┘
    ┌──────┴──────────────────────────────────────────┐
    │                                                   │
    ▼                                                   ▼
┌──────────┐ ┌──────┐ ┌─────┐ ┌────────┐ ┌──────┐ ┌───────┐
│  brew/   │ │ zsh/ │ │vim/ │ │emacs/  │ │wez-  │ │python/│
│          │ │      │ │     │ │        │ │term/ │ │       │
│ Brewfile │ │core/ │ │core/│ │init.el │ │core/ │ │reqs/  │
│ install  │ │plat/ │ │ftpl/│ │lisp/   │ │plat/ │ │tools  │
└──────────┘ └──────┘ └─────┘ └────────┘ └──────┘ └───────┘
    │           │        │        │         │        │
    ▼           ▼        ▼        ▼         ▼        ▼
┌──────────┐ ┌──────┐ ┌─────┐ ┌────────┐ ┌──────┐ ┌───────┐
│  rust/   │ │tmux/ │ │git/ │ │.github/│ │Make- │ │validate│
│          │ │      │ │     │ │workflw/│ │file  │ │.sh     │
│ cargo    │ │.tmux │ │hook/│ │ci.yml  │ │      │ │test_   │
│ rustfmt  │ │.conf │ │     │ │        │ │      │ │install │
└──────────┘ └──────┘ └─────┘ └────────┘ └──────┘ └───────┘
```

## 分层安装策略

```
基础层                编辑器层              终端层              开发层
┌──────────┐      ┌──────────┐      ┌──────────┐      ┌──────────┐
│EditorConfig│     │   Vim    │      │ WezTerm  │      │  Python  │
│   Git     │ ──▶ │  Emacs   │ ──▶ │  Tmux    │ ──▶ │  Rust    │
│   Brew    │      │          │      │          │      │          │
└──────────┘      └──────────┘      └──────────┘      └──────────┘
     │
     ▼  依赖关系
  Brew 为后续所有模块提供包管理基础
  Git 为后续所有模块提供版本控制基础
  EditorConfig 为所有编辑器提供统一缩进规则
```

## 模块依赖关系

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

## 质量保障体系

```
                    ┌─────────────────────┐
                    │   开发阶段           │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │  Git Hooks (本地)    │
                    │  pre-commit: 空格/CRLF│
                    │  commit-msg: 格式提示 │
                    │  pre-push: 分支保护   │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │  GitHub Actions (CI) │
                    │  ┌────────────────┐  │
                    │  │ ShellCheck     │  │
                    │  │ Syntax Check   │  │
                    │  │ Static Tests   │  │
                    │  │ Integration    │  │
                    │  └────────────────┘  │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │  验证脚本 (本地)      │
                    │  validate.sh         │
                    │  test_install.sh     │
                    │  test_integration.sh │
                    └─────────────────────┘
```

## 配置加载流程

### Zsh 启动流程

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

### WezTerm 启动流程

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
