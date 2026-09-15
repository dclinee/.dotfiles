---
layout: home

hero:
  name: "Dotfiles"
  text: "A+ 级模块化配置框架"
  tagline: 支持 Linux/macOS/WSL 三平台，覆盖 Zsh/Vim/Emacs/WezTerm/Tmux 五大编辑器与终端
  actions:
    - theme: brand
      text: 快速开始
      link: /guide/getting-started
    - theme: alt
      text: GitHub
      link: https://github.com/dclinee/.dotfiles

features:
  - title: 一键安装
    details: bootstrap.sh 或 make install 自动完成全部配置，几分钟内获得完整开发环境。
    icon: 🚀
  - title: 跨平台
    details: 完美兼容 Linux (Ubuntu/Debian) 和 macOS，平台差异隔离在 platform/ 目录。
    icon: 🌐
  - title: 模块化设计
    details: 12 个独立模块，每个模块自带 install/check/uninstall/clean/upgrade 脚本。
    icon: 🧩
  - title: Zinit 插件管理
    details: 并行加载和异步安装，懒加载提升启动速度，支持 turbo mode。
    icon: ⚡
  - title: Starship 主题
    details: 现代化提示符，响应式设计，Nerd Font 未安装时自动降级为无图标模式。
    icon: 🎨
  - title: CI 五维保障
    details: ShellCheck + 跨平台语法 + 静态测试 + kcov 覆盖率 + Docker 集成测试。
    icon: ✅
---
