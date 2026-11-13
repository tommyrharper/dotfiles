-- ACP providers ride each CLI's own login (`claude`, `codex login`), so the
-- Claude and ChatGPT subscriptions are billed, not API keys. Not
-- `auth_type = "max"`: that reuses Claude Code's OAuth client from a
-- third-party app. Adapters come from tools.nix. <leader>ap switches to codex.
return {
  {
    "yetone/avante.nvim",
    -- Required since avante's command rewrite; LazyVim's ai.avante extra lacks it.
    dependencies = { { "ColinKennedy/mega.cmdparse", dependencies = { "ColinKennedy/mega.logging" } } },
    opts = { provider = "claude-code" },
    keys = {
      { "<leader>at", "<cmd>Avante toggle<CR>", desc = "Toggle Avante" },
      -- The ai.avante extra declares these without `mode`, so lazy.nvim only
      -- creates the load trigger in normal mode and avante's own visual
      -- mappings never exist until something else loads the plugin - asking
      -- about a selection is the main reason to reach for it.
      { "<leader>aa", "<cmd>AvanteAsk<CR>", mode = { "n", "v" }, desc = "Ask Avante" },
      { "<leader>ae", "<cmd>AvanteEdit<CR>", mode = { "n", "v" }, desc = "Edit Avante" },
    },
  },
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>a", group = "ai/avante", icon = { icon = "󰚩 ", color = "green" }, mode = { "n", "x" } },
      },
    },
  },
}
