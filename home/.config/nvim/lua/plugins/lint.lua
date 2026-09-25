-- LazyVim's lang.markdown extra lints every markdown buffer with
-- markdownlint-cli2 on read, write and InsertLeave. These are notes, not
-- published docs, and its loudest rule is a 2-vs-4-space list indent opinion.
-- Everything else the extra brings (render-markdown, marksman, prettier) stays.
-- On demand: :lua require("lint").try_lint("markdownlint-cli2")
return {
  {
    "mfussenegger/nvim-lint",
    opts = { linters_by_ft = { markdown = {} } },
  },
}
