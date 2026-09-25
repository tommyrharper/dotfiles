-- Loaded before lazy.nvim starts. LazyVim's own options apply first; only
-- deltas belong here.

-- Format on demand (<leader>cf), never on save. Every formatter rewrites the
-- whole buffer, so on-save turns a one-line edit to a hand-formatted file into
-- a few hundred lines of churn - nixfmt and stylua do exactly that to this
-- repo. <leader>uf / <leader>uF toggle it back on per buffer or globally.
vim.g.autoformat = false
