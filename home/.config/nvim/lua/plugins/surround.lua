-- `gsac` wraps a selection in a markdown code fence. mini.surround's `?`
-- prompt takes no newlines, so a fence needs its own surrounding.
return {
  {
    "nvim-mini/mini.surround",
    opts = { custom_surroundings = { c = { output = { left = "```\n", right = "\n```" } } } },
  },
}
