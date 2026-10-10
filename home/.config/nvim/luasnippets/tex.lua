-- Loaded by the from_lua loader in lua/plugins/luasnip.lua, keyed on filetype.
local ls = require("luasnip")
local s, t, i = ls.snippet, ls.text_node, ls.insert_node
local fmta = require("luasnip.extras.fmt").fmta
local rep = require("luasnip.extras").rep

-- vimtex's syntax engine, so these need the lang.tex extra loaded.
local function in_math()
  return vim.fn["vimtex#syntax#in_mathzone"]() == 1
end

-- Math triggers are not word-bounded: "//" and a trailing "sr" follow symbols.
local function math(trig, nodes)
  return s({ trig = trig, snippetType = "autosnippet", condition = in_math, wordTrig = false }, nodes)
end

return {
  s({ trig = "mk", snippetType = "autosnippet" }, fmta("$<>$", { i(1) })),
  s({ trig = "dm", snippetType = "autosnippet" }, fmta("\\[\n  <>\n\\]", { i(1) })),
  s({ trig = "env" }, fmta("\\begin{<>}\n  <>\n\\end{<>}", { i(1), i(2), rep(1) })),
  math("//", fmta("\\frac{<>}{<>}", { i(1), i(2) })),
  math("td", fmta("^{<>}", { i(1) })),
  math("sr", t("^{2}")),
}
