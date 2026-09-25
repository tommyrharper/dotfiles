-- Loaded on VeryLazy, after LazyVim's own keymaps, so anything here wins.

-- Pasting over a visual selection keeps the yanked text in the register
-- instead of swapping in whatever was overwritten, so the same text can be
-- pasted over several selections in a row.
vim.cmd([[ xnoremap <expr> p 'pgv"'.v:register.'y' ]])
