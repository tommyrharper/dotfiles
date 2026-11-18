-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- avante's own `windows.wrap` default is true, but the sidebar window still
-- comes up with wrap off, so responses scroll sideways.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "Avante", "AvanteInput", "AvanteSelectedFiles", "AvanteTodos" },
  callback = function(ev)
    vim.schedule(function()
      for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
        vim.wo[win].wrap = true
        vim.wo[win].linebreak = true
      end
    end)
  end,
})
