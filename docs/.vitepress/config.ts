import { defineConfig } from 'vitepress'

export default defineConfig({
  lang: 'zh-CN',
  title: 'Dotfiles',
  description: 'A+ 级模块化 dotfiles 配置框架',
  cleanUrls: true,

  themeConfig: {
    // 顶部导航
    nav: [
      { text: '首页', link: '/' },
      { text: '指南', link: '/guide/getting-started' },
      { text: '模块', link: '/modules/overview' },
      { text: '架构', link: '/architecture/overview' },
      { text: '决策', link: '/decisions/' },
      { text: '贡献', link: '/contribute/' },
      { text: 'Changelog', link: '/changelog' },
      { text: 'GitHub', link: 'https://github.com/dclinee/.dotfiles' }
    ],

    // 侧边栏按 section 分组
    sidebar: {
      '/guide/': [
        {
          text: '指南',
          items: [
            { text: '快速开始', link: '/guide/getting-started' },
            { text: '安装方式', link: '/guide/installation' },
            { text: '国内镜像', link: '/guide/mirror' }
          ]
        }
      ],
      '/modules/': [
        {
          text: '模块总览',
          items: [
            { text: '模块总览', link: '/modules/overview' }
          ]
        },
        {
          text: '配置模块',
          items: [
            { text: 'Zsh', link: '/modules/zsh' },
            { text: 'Vim', link: '/modules/vim' },
            { text: 'Emacs', link: '/modules/emacs' },
            { text: 'WezTerm', link: '/modules/wezterm' },
            { text: 'Tmux', link: '/modules/tmux' }
          ]
        },
        {
          text: '工具链模块',
          items: [
            { text: 'Python', link: '/modules/python' },
            { text: 'Rust', link: '/modules/rust' },
            { text: 'Homebrew', link: '/modules/brew' }
          ]
        },
        {
          text: '其他模块',
          items: [
            { text: 'SSH', link: '/modules/ssh' },
            { text: 'Git', link: '/modules/git' },
            { text: 'PowerShell', link: '/modules/pwsh' },
            { text: 'Docker', link: '/modules/docker' }
          ]
        }
      ],
      '/architecture/': [
        {
          text: '架构',
          items: [
            { text: '系统架构', link: '/architecture/overview' },
            { text: '分层安装策略', link: '/architecture/install-order' },
            { text: '模块依赖关系', link: '/architecture/dependencies' },
            { text: '配置加载流程', link: '/architecture/loading-flow' }
          ]
        }
      ],
      '/decisions/': [
        {
          text: '架构决策记录',
          items: [
            { text: '索引', link: '/decisions/' },
            { text: 'ADR-001 bootstrap.sh 主入口', link: '/decisions/adr-001' },
            { text: 'ADR-002 分层安装顺序', link: '/decisions/adr-002' },
            { text: 'ADR-003 zinit 插件管理', link: '/decisions/adr-003' },
            { text: 'ADR-004 core/platform 分层', link: '/decisions/adr-004' },
            { text: 'ADR-005 safe_symlink', link: '/decisions/adr-005' },
            { text: 'ADR-006 Git 凭证 cache', link: '/decisions/adr-006' },
            { text: 'ADR-007 国内镜像回退', link: '/decisions/adr-007' },
            { text: 'ADR-008 步骤追踪机制', link: '/decisions/adr-008' },
            { text: 'ADR-009 Vim 9+ 兼容', link: '/decisions/adr-009' },
            { text: 'ADR-010 Brewfile 分层', link: '/decisions/adr-010' }
          ]
        }
      ],
      '/contribute/': [
        {
          text: '贡献',
          items: [
            { text: '贡献指南', link: '/contribute/' },
            { text: '测试与验证', link: '/contribute/testing' }
          ]
        }
      ]
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/dclinee/.dotfiles' }
    ],

    // 本地搜索
    search: {
      provider: 'local'
    },

    // 侧边大纲目录到 h3
    outline: {
      level: [2, 3],
      label: '本页目录'
    },

    docFooter: {
      prev: '上一页',
      next: '下一页'
    },

    lastUpdated: {
      text: '最后更新'
    }
  }
})
