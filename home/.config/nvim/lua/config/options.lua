-- Loaded before lazy.nvim starts. LazyVim's own options apply first; only
-- deltas belong here.

-- Format on demand (<leader>cf), never on save. Every formatter rewrites the
-- whole buffer, so on-save turns a one-line edit to a hand-formatted file into
-- a few hundred lines of churn - nixfmt and stylua do exactly that to this
-- repo. <leader>uf / <leader>uF toggle it back on per buffer or globally.
vim.g.autoformat = false

-- Must precede filetype detection: an empty or preamble-less .tex file is
-- detected as plaintex otherwise, and vimtex only attaches to tex.
vim.g.tex_flavor = "latex"

-- Skim is the only macOS viewer with working SyncTeX inverse search; Preview
-- has none. The matching half lives in Skim > Settings > Sync, as a Custom
-- preset running `nvim --headless -c "VimtexInverseSearch %line '%file'"`.
vim.g.vimtex_view_method = "skim"
vim.g.vimtex_view_skim_sync = 1
vim.g.vimtex_view_skim_activate = 1

-- Warnings are routine in LaTeX; only errors are worth stealing focus for.
vim.g.vimtex_quickfix_open_on_warning = 0

-- latexmk's aux files are noise in a source tree.
vim.g.vimtex_compiler_latexmk = { out_dir = "build" }
