-- Installed but not activated: tokyonight stays LazyVim's default until
-- <leader>uC picks a winner. rose-pine moon is what wezterm.lua uses, and the
-- transparency lets the terminal's own background show through.
-- To make it stick, add: { "LazyVim/LazyVim", opts = { colorscheme = "rose-pine" } }
-- To drop it, delete this file.
return {
  {
    "rose-pine/neovim",
    name = "rose-pine",
    lazy = true,
    opts = {
      dark_variant = "moon",
      styles = { italic = false, transparency = true },
    },
  },
}
