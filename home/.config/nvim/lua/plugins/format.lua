return {
  {
    -- Formatting is on demand, never on save: <leader>F formats the buffer.
    -- Format-on-save always rewrites the whole buffer, so in a project that
    -- has never been formatted it turns a one-line fix into a few hundred
    -- lines of churn - and <Esc> is mapped to :w (see keys.lua), so it would
    -- fire constantly.
    --
    -- Whole buffer is the only unit on offer. conform can take a range, but
    -- for a formatter with no range support of its own (prettier is one) it
    -- formats everything and then applies only the hunks inside the range,
    -- and that silently applied nothing here - gq via formatexpr and a visual
    -- selection both left the buffer untouched. Better one key that works
    -- than three that quietly do not.
    'stevearc/conform.nvim',
    keys = {
      {
        '<leader>F',
        -- fallback covers a buffer whose formatter is missing or fails, which
        -- is every python buffer until mason has finished installing ruff
        function() require('conform').format({ lsp_format = 'fallback' }) end,
        desc = 'Format',
      },
    },
    opts = {
      -- lua and nix are deliberately absent. stylua and nixfmt disagree with
      -- this repo's own hand-formatting wholesale (66 changed lines in a
      -- 27-line plugin file, 341 in a 122-line tools.nix), so mapping them
      -- would make <leader>F a trap in exactly the files it is most tempting
      -- to press it in. prettier, by contrast, leaves the committed yaml/json
      -- untouched. Each formatter still reads the edited project's own config
      -- (.prettierrc, .editorconfig, pyproject.toml), not one from here.
      formatters_by_ft = {
        python = { 'ruff_format' },
        markdown = { 'prettier' },
        yaml = { 'prettier' },
        json = { 'prettier' },
        html = { 'prettier' },
        css = { 'prettier' },
      },
    },
  },
}
