-- ===================================
-- Neovim AI 编程插件集
-- ===================================
--
-- 包含四大 AI 能力:
--   1. Copilot — 云端代码补全（需 GitHub 账号）
--   2. CodeCompanion — 通用 LLM 对话（兼容 OpenAI / Ollama / Anthropic）
--   3. CopilotChat — GitHub Copilot Chat（需 Copilot 订阅）
--   4. Continue — 开源 AI 编程助手（支持本地/云端模型）
--
-- 使用建议:
--   - 免费离线: Ollama + CodeCompanion
--   - 最强补全: GitHub Copilot
--   - 全功能 IDE: Continue（Cursor 开源替代）
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
  -- 3. CodeCompanion — 通用 LLM 对话
  -- ===================================
  -- 支持 OpenAI / Anthropic / Ollama / 国产兼容 API
  -- 使用 Ollama: export OLLAMA_HOST=localhost:11434
  -- 使用 OpenAI: export OPENAI_API_KEY=sk-xxx
  {
    "olimorris/codecompanion.nvim",
    keys = {
      { "<leader>cc", "<cmd>CodeCompanionChat<CR>", desc = "AI Chat" },
      { "<leader>ci", "<cmd>CodeCompanionInline<CR>", desc = "内联补全", mode = { "v" } },
      { "<leader>ca", "<cmd>CodeCompanionActions<CR>", desc = "AI 操作" },
    },
    config = function()
      require("codecompanion").setup({
        strategies = {
          chat = {
            adapter = "ollama",
          },
          inline = {
            adapter = "ollama",
          },
        },
        adapters = {
          ollama = function()
            return require("codecompanion.adapters").extend("ollama", {
              name = "ollama",
              schema = {
                model = {
                  -- 默认模型: llama3.2 (8B)
                  -- 代码专用: codellama:7b
                  default = "llama3.2",
                },
              },
            })
          end,
          -- 如需使用 OpenAI:
          -- openai = function()
          --   return require("codecompanion.adapters").extend("openai", {
          --     schema = {
          --       model = { default = "gpt-4o-mini" },
          --     },
          --   })
          -- end,
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