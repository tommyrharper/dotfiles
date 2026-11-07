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
    keys = { { "<leader>at", "<cmd>Avante toggle<CR>", desc = "Toggle Avante" } },
  },
}
