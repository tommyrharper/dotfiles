-- Loaded on VeryLazy, after LazyVim's own keymaps, so anything here wins.

-- Pasting over a visual selection keeps the yanked text in the register
-- instead of swapping in whatever was overwritten, so the same text can be
-- pasted over several selections in a row.
vim.cmd([[ xnoremap <expr> p 'pgv"'.v:register.'y' ]])

-- Lint on demand. Markdown has no linter registered (see
-- lua/plugins/lint.lua), so markdownlint-cli2 is named explicitly there;
-- every other filetype runs whatever nvim-lint already has for it.
vim.keymap.set("n", "<leader>cL", function()
  require("lint").try_lint(vim.bo.filetype == "markdown" and "markdownlint-cli2" or nil)
end, { desc = "Lint buffer" })
