-- Same ACP adapters as avante.lua (tools.nix), riding the `claude` and
-- `codex login` sessions, so the subscriptions are billed, not API keys.
-- Switch to codex inside a chat with `ga`. <leader>a is avante's, so <leader>C.
return {
  {
    "olimorris/codecompanion.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "nvim-treesitter/nvim-treesitter" },
    cmd = { "CodeCompanion", "CodeCompanionChat", "CodeCompanionActions", "CodeCompanionCmd" },
    keys = {
      { "<leader>Cc", "<cmd>CodeCompanionChat Toggle<CR>", mode = { "n", "v" }, desc = "Toggle CodeCompanion Chat" },
      { "<leader>Ca", "<cmd>CodeCompanionActions<CR>", mode = { "n", "v" }, desc = "CodeCompanion Actions" },
    },
    opts = {
      interactions = { chat = { adapter = "claude_code" } },
      adapters = {
        acp = {
          codex = function()
            -- Defaults to "api-key".
            return require("codecompanion.adapters").extend("codex", { defaults = { auth_method = "chat-gpt" } })
          end,
        },
      },
    },
  },
  {
    "folke/which-key.nvim",
    opts = { spec = { { "<leader>C", group = "codecompanion", mode = { "n", "x" } } } },
  },
}
