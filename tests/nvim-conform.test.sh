#!/usr/bin/env bash
# Formatting is on demand, never on save (vim.g.autoformat = false in
# home/.config/nvim/lua/config/options.lua). LazyVim turns format-on-save on by
# default, and its extras map stylua to lua and nixfmt to nix - so if that flag
# is lost, saving a one-character edit to any .lua file or to home.nix rewrites
# the whole file. That is what this guards.
#
# Drives the real config through a real nvim rather than loading the spec:
#   1. saving a buffer changes nothing, in filetypes that DO have a formatter
#   2. <leader>cf formats the whole buffer on request
#
# The User VeryLazy autocmd is fired by hand. lazy.nvim only emits it once a UI
# attaches, so under --headless neither LazyVim's keymaps nor conform's
# BufWritePre hook would ever be installed - and then check 1 would pass for
# the wrong reason, on a config that actually reformats on save.
set -u
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

command -v nvim >/dev/null 2>&1 || { echo "skip: nvim not installed"; exit 0; }

data_home="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
[ -d "$data_home/lazy/conform.nvim" ] \
  || { echo "skip: conform.nvim not cloned yet - open nvim once"; exit 0; }
[ -x "$data_home/mason/bin/stylua" ] \
  || { echo "skip: mason has not installed stylua yet"; exit 0; }

tmp=$(dotfiles_test_tmproot nvim-conform)

ready='lua vim.api.nvim_exec_autocmds("User", {pattern="VeryLazy", modeline=false})
  if not vim.wait(15000, function() return vim.fn.maparg("<leader>cf","n") ~= "" end, 200) then
    vim.cmd("cquit 3")
  end'

# Run nvim against the repo's own config, with LazyVim fully loaded.
in_nvim() {
  local file=$1; shift
  XDG_CONFIG_HOME="$ROOT/home/.config" nvim --headless "+e $file" -c "$ready" "$@" +qa \
    >/dev/null 2>&1 \
    || fail "nvim exited non-zero (LazyVim never finished loading?) on $file"
}

# Deliberately misformatted, in a filetype LazyVim maps a formatter for.
unformatted_lua() {
  printf 'local   t = {a=1,   b=2}\nreturn    t\n' > "$1"
}

# 1. A plain write must not touch the buffer - that is the whole point.
unformatted_lua "$tmp/save.lua"
cp "$tmp/save.lua" "$tmp/save.lua.orig"
in_nvim "$tmp/save.lua" +w
cmp -s "$tmp/save.lua" "$tmp/save.lua.orig" \
  || fail "saving a lua buffer ran stylua; formatting is supposed to be on demand"

printf '{ a = 1;   b = 2; }\n' > "$tmp/sample.nix"
cp "$tmp/sample.nix" "$tmp/sample.nix.orig"
in_nvim "$tmp/sample.nix" +w
cmp -s "$tmp/sample.nix" "$tmp/sample.nix.orig" \
  || fail "saving a nix buffer ran nixfmt; formatting is supposed to be on demand"

# 2. The whole buffer, on request. <leader> is a space, so the mapping is " cf".
unformatted_lua "$tmp/all.lua"
in_nvim "$tmp/all.lua" '+lua vim.fn.feedkeys(" cf", "x"); vim.wait(5000)' +w
grep -q '^local t = { a = 1, b = 2 }$' "$tmp/all.lua" \
  || fail "<leader>cf did not format the buffer: $(cat "$tmp/all.lua")"
grep -q '^return t$' "$tmp/all.lua" \
  || fail "<leader>cf formatted only part of the buffer: $(cat "$tmp/all.lua")"

pass "conform formats on <leader>cf only, never on save"
