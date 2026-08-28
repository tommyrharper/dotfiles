#!/usr/bin/env bash
# The Python LSP plugin spec is wired up as intended: both servers in mason's
# ensure_installed, ruff's hover disabled so it does not fight basedpyright,
# basedpyright on typeCheckingMode "basic", and conform formatting on save.
#
# This loads the spec as real Lua rather than grepping it, so a typo in a key
# or a syntax error fails here. Installing the servers needs the network and a
# non-headless nvim (mason-lspconfig skips ensure_installed when headless), so
# that part is deliberately not attempted; see README for the manual check.
set -u
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

command -v nvim >/dev/null 2>&1 || { echo "skip: nvim not installed"; exit 0; }

tmp=$(dotfiles_test_tmproot nvim-python-lsp)
cat > "$tmp/check.lua" <<'LUA'
local spec = dofile(os.getenv('SPEC'))
local by_repo = {}
for _, p in ipairs(spec) do by_repo[p[1]] = p end

local function want(cond, msg)
  if not cond then io.stderr:write(msg .. '\n'); os.exit(1) end
end

want(by_repo['mason-org/mason.nvim'], 'mason.nvim missing from the spec')

local ensure = (by_repo['mason-org/mason-lspconfig.nvim'] or {}).opts or {}
ensure = ensure.ensure_installed or {}
want(vim.tbl_contains(ensure, 'basedpyright'), 'basedpyright missing from ensure_installed')
want(vim.tbl_contains(ensure, 'ruff'), 'ruff missing from ensure_installed')

-- Run nvim-lspconfig's config body and read back what it registered.
local lspconfig = by_repo['neovim/nvim-lspconfig']
want(lspconfig and lspconfig.config, 'no nvim-lspconfig spec with a config function')
lspconfig.config()

local bp = vim.lsp.config['basedpyright']
want(vim.tbl_get(bp, 'settings', 'basedpyright', 'analysis', 'typeCheckingMode') == 'basic',
  'basedpyright typeCheckingMode is not "basic"')

-- ruff's on_attach must switch hover off, or K races basedpyright's docs.
local fake = { server_capabilities = { hoverProvider = true } }
vim.lsp.config['ruff'].on_attach(fake)
want(fake.server_capabilities.hoverProvider == false, 'ruff on_attach does not disable hover')

local conform = (by_repo['stevearc/conform.nvim'] or {}).opts or {}
want(vim.deep_equal(conform.formatters_by_ft.python, { 'ruff_format' }),
  'conform does not format python with ruff_format')
want(conform.format_on_save.timeout_ms == 500, 'conform format_on_save timeout is not 500ms')
want(conform.format_on_save.lsp_format == 'fallback', 'conform does not fall back to LSP formatting')
LUA

SPEC="$ROOT/home/.config/nvim/lua/plugins/lsp.lua" \
  nvim --clean -l "$tmp/check.lua" >/dev/null 2>"$tmp/err" \
  || fail "$(cat "$tmp/err")"

pass "nvim python LSP spec installs basedpyright + ruff and formats with conform"
