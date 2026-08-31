-- Language servers and completion for Python and TypeScript/TSX. Formatting
-- is conform.nvim's, in format.lua, on <leader>F for every filetype at once.
-- The servers are installed by mason rather than Nix, so this file is the
-- single source of truth for what these buffers get.
return {
  -- mason installs the server binaries into ~/.local/share/nvim/mason/bin.
  {
    'mason-org/mason.nvim',
    opts = {},
  },

  -- Bridges mason's package names to lspconfig's server names and, in
  -- mason-lspconfig v2, calls vim.lsp.enable() for each installed server
  -- automatically. ensure_installed fetches anything missing on startup.
  {
    'mason-org/mason-lspconfig.nvim',
    dependencies = { 'mason-org/mason.nvim', 'neovim/nvim-lspconfig' },
    opts = {
      ensure_installed = { 'basedpyright', 'ruff', 'ts_ls' },
    },
  },

  -- Per-server settings. nvim-lspconfig ships the cmd/filetypes/root markers
  -- for each server, and vim.lsp.config extends that, so only the deltas
  -- belong here. ts_ls needs none, so it's not mentioned below.
  {
    'neovim/nvim-lspconfig',
    config = function()
      -- basedpyright: type checking, completion, and navigation.
      vim.lsp.config('basedpyright', {
        settings = {
          basedpyright = {
            analysis = {
              typeCheckingMode = 'basic',
            },
          },
        },
      })

      -- ruff: linting and code actions only. Hover is switched off so K keeps
      -- showing basedpyright's docstrings instead of ruff's thinner popup
      -- winning the race between two attached servers.
      vim.lsp.config('ruff', {
        on_attach = function(client)
          client.server_capabilities.hoverProvider = false
        end,
      })

      -- Autotriggered completion off the built-in LSP source (nvim 0.11+),
      -- so no separate completion plugin is needed.
      vim.o.completeopt = 'menu,menuone,noinsert,popup'
      vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(args)
          vim.lsp.completion.enable(true, args.data.client_id, args.buf, { autotrigger = true })
        end,
      })
    end,
  },
}
