-- CSD3: nil comes from tools.nix, not a mason cargo build.
return {
  {
    "neovim/nvim-lspconfig",
    opts = { servers = { nil_ls = { mason = vim.env.DOTFILES_CSD3_INSIDE == nil } } },
  },
}
