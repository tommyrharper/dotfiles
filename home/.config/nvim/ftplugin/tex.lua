-- LazyVim's wrap_spell autocmd lists plaintex, not tex, so prose settings for
-- real LaTeX buffers land here.
vim.opt_local.wrap = true
vim.opt_local.linebreak = true
vim.opt_local.breakindent = true
vim.opt_local.spell = true
vim.opt_local.spelllang = "en_gb"

-- vimtex conceals $...$ and \alpha only from level 2 up.
vim.opt_local.conceallevel = 2

-- Soft wrap at the window edge; gq still reflows on request. Without removing
-- "t", every typed line past textwidth gets a hard break instead.
vim.opt_local.textwidth = 0
vim.opt_local.formatoptions:remove("t")

-- One wrapped paragraph is one line to j/k otherwise.
vim.keymap.set({ "n", "x" }, "j", "gj", { buffer = true })
vim.keymap.set({ "n", "x" }, "k", "gk", { buffer = true })
