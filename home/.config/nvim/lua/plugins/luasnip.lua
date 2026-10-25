-- LazyVim's luasnip extra loads VSCode-JSON snippets only. LaTeX needs the Lua
-- format: regex triggers, autoexpansion, and conditions on cursor context.
return {
  {
    "L3MON4D3/LuaSnip",
    opts = { enable_autosnippets = true },
    config = function(_, opts)
      require("luasnip").setup(opts)
      require("luasnip.loaders.from_lua").lazy_load({
        paths = { vim.fn.stdpath("config") .. "/luasnippets" },
      })
    end,
  },
}
