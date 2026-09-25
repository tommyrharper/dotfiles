-- wezterm.lua is rose-pine-moon too, and transparency lets its background and
-- opacity show through instead of nvim painting over them. LazyVim ships only
-- tokyonight and catppuccin, so this is a plain plugin spec.
return {
  {
    "rose-pine/neovim",
    name = "rose-pine",
    lazy = true,
    opts = {
      styles = { italic = false, transparency = true },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "rose-pine-moon" },
  },
}
