local o = vim.opt
vim.g.mapleader = ' '          -- space is the leader key
o.expandtab = true             -- spaces, not tabs
o.shiftwidth = 2               -- 2 spaces per indent level
o.number = true                -- kept on for intent; statuscolumn below fully controls what's drawn
o.relativenumber = true        -- required so cursor movement alone triggers a statuscolumn redraw
o.ignorecase = true            -- search is case-insensitive by default
o.smartcase = true             -- case-sensitive only if i type a capital
o.clipboard = 'unnamedplus'    -- share the system clipboard
o.scrolloff = 16               -- keep cursor away from the screen edge
o.undofile = true              -- persistent undo across sessions
o.mouse = ''                   -- no mouse in nvim; also lets Herdr keep host mouse capture off so Escape isn't swallowed

-- Gutter shows both the absolute line number and the relative offset for
-- every line at once (plain 'number'+'relativenumber' hybrid mode only
-- shows the cursor's own line as absolute). CursorLineNr/LineNr/Comment
-- are existing highlight groups so this stays theme-agnostic.
function _G.StatusColumnNumbers()
  local abs_hl = vim.v.relnum == 0 and 'CursorLineNr' or 'LineNr'
  return string.format('%%#%s#%3d%%* %%#Comment#%3d%%* ', abs_hl, vim.v.lnum, vim.v.relnum)
end
o.statuscolumn = '%!v:lua.StatusColumnNumbers()'

