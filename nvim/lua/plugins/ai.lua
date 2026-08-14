-- ===================================
-- Neovim AI 编程插件集
-- ===================================
--
-- 包含六大 AI 能力:
--   1. Copilot — 云端代码补全（需 GitHub 账号）
--   2. CodeCompanion — 通用 LLM 对话（支持 DeepSeek / 豆包 / Ollama / OpenAI）
--   3. CopilotChat — GitHub Copilot Chat（需 Copilot 订阅）
--   4. Continue — 开源 AI 编程助手（支持本地/云端模型）
--   5. avante — Cursor 风格 AI 编程（原生支持 DeepSeek）
--   6. DeepSeek/豆包 — 国产模型适配器（CodeCompanion 内置）
--
-- 使用建议:
--   - 国产首选: DeepSeek（便宜、代码能力强）
--   - 免费离线: Ollama + CodeCompanion
--   - 最强补全: GitHub Copilot
--   - Cursor 替代: avante.nvim
--
-- 环境变量:
--   export DEEPSEEK_API_KEY=sk-xxx
--   export DOUBAO_API_KEY=xxx
--
-- 启用/禁用: 注释掉不需要的插件即可

return {
  -- ===================================
  -- 1. GitHub Copilot 代码补全
  -- ===================================
  -- 首次使用: :Copilot auth 完成认证
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    config = function()
      require("copilot").setup({
        suggestion = {
          enabled = true,
          auto_trigger = true,
          hide_during_completion = true,
          keymap = {
            accept = "<Tab>",
            accept_word = "<C-/>",
            accept_line = "<C-\\>",
            next = "<C-]>",
            prev = "<C-[>",
            dismiss = "<C-e>",
          },
        },
        panel = {
          enabled = false,
        },
        filetypes = {
          markdown = true,
          help = false,
        },
      })
    end,
  },

  -- ===================================
  -- 2. Copilot Chat（对话式 AI 编程）
  -- ===================================
  -- 快捷键: :CopilotChat 打开对话窗口
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    branch = "main",
    cmd = "CopilotChat",
    keys = {
      { "<leader>aa", "<cmd>CopilotChat<CR>", desc = "AI 对话" },
      { "<leader>ae", "<cmd>CopilotChatExplain<CR>", desc = "解释代码", mode = { "v" } },
      { "<leader>ar", "<cmd>CopilotChatReview<CR>", desc = "代码审查", mode = { "v" } },
      { "<leader>at", "<cmd>CopilotChatTests<CR>", desc = "生成测试", mode = { "v" } },
      { "<leader>af", "<cmd>CopilotChatFix<CR>", desc = "修复代码", mode = { "v" } },
      { "<leader>ao", "<cmd>CopilotChatOptimize<CR>", desc = "优化代码", mode = { "v" } },
    },
    config = function()
      require("CopilotChat").setup({
        auto_insert_mode = true,
        show_help = true,
        question_header = "## You ",
        answer_header = "## Copilot ",
        window = {
          width = 0.4,
        },
        context = "buffer",
      })
    end,
  },

  -- ===================================
  -- 3. CodeCompanion — 通用 LLM 对话（DeepSeek / 豆包 / Ollama）
  -- ===================================
  -- 默认适配器: DeepSeek（国产首选，便宜且代码能力强）
  -- 切换适配器: :CodeCompanionChat 后选模型
  --
  -- 环境变量:
  --   export DEEPSEEK_API_KEY=sk-xxx
  --   export DOUBAO_API_KEY=xxx
  {
    "olimorris/codecompanion.nvim",
    keys = {
      { "<leader>cc", "<cmd>CodeCompanionChat<CR>", desc = "AI Chat" },
      { "<leader>cd", "<cmd>CodeCompanionChat<CR>", desc = "DeepSeek", hidden = true },
      { "<leader>ci", "<cmd>CodeCompanionInline<CR>", desc = "内联补全", mode = { "v" } },
      { "<leader>ca", "<cmd>CodeCompanionActions<CR>", desc = "AI 操作" },
    },
    config = function()
      require("codecompanion").setup({
        strategies = {
          chat = {
            adapter = "deepseek",
          },
          inline = {
            adapter = "deepseek",
          },
        },
        adapters = {
          -- ====== DeepSeek 适配器 ======
          deepseek = function()
            return require("codecompanion.adapters").extend("openai_compatible", {
              name = "deepseek",
              env = {
                api_key = "DEEPSEEK_API_KEY",
              },
              url = "https://api.deepseek.com/v1",
              schema = {
                model = {
                  default = "deepseek-chat",
                  choices = {
                    "deepseek-chat",     -- 通用对话
                    "deepseek-reasoner", -- 深度推理
                  },
                },
              },
            })
          end,
          -- ====== 豆包（火山引擎）适配器 ======
          doubao = function()
            return require("codecompanion.adapters").extend("openai_compatible", {
              name = "doubao",
              env = {
                api_key = "DOUBAO_API_KEY",
              },
              url = "https://ark.cn-beijing.volces.com/api/v3",
              schema = {
                model = {
                  default = "doubao-pro-32k",
                  choices = {
                    "doubao-pro-32k",   -- 旗舰版（32K 上下文）
                    "doubao-lite-32k",  -- 轻量版（32K 上下文）
                  },
                },
              },
            })
          end,
          -- ====== Ollama 本地适配器（离线免费）======
          ollama = function()
            return require("codecompanion.adapters").extend("ollama", {
              name = "ollama",
              schema = {
                model = {
                  default = "llama3.2",
                  choices = {
                    "llama3.2",
                    "codellama:7b",
                  },
                },
              },
            })
          end,
        },
        display = {
          chat = {
            window = {
              width = 0.35,
            },
          },
        },
      })
    end,
  },

  -- ===================================
  -- 5. avante.nvim — Cursor 风格 AI 编程（原生支持 DeepSeek）
  -- ===================================
  -- 快捷键:
  --   <leader>ah   :AvanteAsk 询问
  --   <leader>ar   :AvanteEdit 编辑
  --   <leader>af   :AvanteFocus 聚焦
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    version = false,
    keys = {
      { "<leader>ah", "<cmd>AvanteAsk<CR>", desc = "Avante 询问" },
      { "<leader>ag", "<cmd>AvanteEdit<CR>", desc = "Avante 编辑" },
      { "<leader>ab", "<cmd>AvanteFocus<CR>", desc = "Avante 聚焦" },
      { "<leader>av", "<cmd>AvanteRefresh<CR>", desc = "Avante 刷新" },
    },
    build = "make",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "echasnovski/mini.icons",
      {
        "MeanderingProgrammer/render-markdown.nvim",
        opts = {
          file_types = { "markdown", "Avante" },
        },
        ft = { "markdown", "Avante" },
      },
    },
    config = function()
      require("avante").setup({
        ---@alias Provider "claude" | "openai" | "azure" | "gemini" | "cohere" | "copilot" | "deepseek"
        provider = "deepseek",
        -- 自动建议（Cursor 风格补全）
        auto_suggestions_provider = "deepseek",
        vendors = {
          -- DeepSeek 配置
          deepseek = {
            __inherited_from = "openai",
            api_key_name = "DEEPSEEK_API_KEY",
            endpoint = "https://api.deepseek.com/v1",
            model = "deepseek-chat",
            max_tokens = 4096,
          },
          -- 豆包配置
          doubao = {
            __inherited_from = "openai",
            api_key_name = "DOUBAO_API_KEY",
            endpoint = "https://ark.cn-beijing.volces.com/api/v3",
            model = "doubao-pro-32k",
            max_tokens = 4096,
          },
        },
        behaviour = {
          auto_suggestions = false,  -- 默认关闭自动建议（避免与 Copilot 冲突）
          auto_set_highlight_group = true,
          auto_set_keymaps = true,
          auto_apply_diff_after_generation = false,
          support_paste_from_clipboard = true,
        },
        mappings = {
          ask = "<leader>ah",
          edit = "<leader>ag",
          refresh = "<leader>av",
          diff = {
            ours = "co",
            theirs = "ct",
            all_theirs = "ca",
            both = "cb",
            cursor = "cc",
            next = "]x",
            prev = "[x",
          },
          suggestion = {
            accept = "<Tab>",
            next = "<C-]>",
            prev = "<C-[>",
            dismiss = "<C-e>",
          },
          jump = {
            next = "]]",
            prev = "[[",
          },
          submit = {
            normal = "<CR>",
            insert = "<C-s>",
          },
          toggle = {
            debug = "<leader>ad",
            hint = "<leader>ay",
          },
        },
        windows = {
          width = 30,
          sidebar_header = {
            enabled = true,
            align = "center",
            rounded = true,
          },
        },
        hints = { enabled = true },
      })
    end,
  },

  -- ===================================
  -- 4. Continue — 开源 AI IDE（Cursor 替代）
  -- ===================================
  -- Web 界面，支持多种模型，功能完整
  -- :Continue 打开侧边栏
  -- 首次运行自动下载 Continue Server
  {
    "Continue-Dev/continue.nvim",
    cmd = "Continue",
    keys = {
      { "<leader>ac", "<cmd>Continue<CR>", desc = "Continue AI" },
    },
    config = function()
      require("continue").setup({
        server = {
          settings = {
            -- 模型配置通过 Continue 的 config.json 管理
            -- 路径: ~/.continue/config.json
            -- 默认使用 Ollama + llama3.2
          },
        },
      })
    end,
  },
}