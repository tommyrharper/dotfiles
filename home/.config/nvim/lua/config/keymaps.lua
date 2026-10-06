-- Loaded on VeryLazy, after LazyVim's own keymaps, so anything here wins.

-- Paste over a selection without clobbering the register.
vim.cmd([[ xnoremap <expr> p 'pgv"'.v:register.'y' ]])

-- Markdown has no linter registered, so name one.
vim.keymap.set("n", "<leader>cL", function()
  require("lint").try_lint(vim.bo.filetype == "markdown" and "markdownlint-cli2" or nil)
end, { desc = "Lint buffer" })
