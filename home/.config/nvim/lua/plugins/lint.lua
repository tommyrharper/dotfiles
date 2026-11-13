-- lang.markdown lints every markdown buffer. On demand instead: <leader>cL
return {
  {
    "mfussenegger/nvim-lint",
    opts = { linters_by_ft = { markdown = {} } },
  },
}
