-- Edit a directory as a buffer. LazyVim's own explorer keeps <leader>e.
return {
  {
    "stevearc/oil.nvim",
    opts = { view_options = { show_hidden = true } },
    keys = { { "<leader>o", "<cmd>Oil<cr>", desc = "Oil (parent dir)" } },
  },
}
