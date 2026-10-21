#!/usr/bin/env bash
# mini.surround is the LazyVim coding extra (gsa/gsd/gsr), plus one non-stock
# surrounding: `c` outputs a markdown code fence. Two things to pin down:
#
#   1. The extra stays enabled. `:LazyExtras` rewrites lazyvim.json wholesale,
#      so a stray toggle is a one-line diff that is easy to miss in review -
#      same hazard tests/nvim-lang-support.test.sh guards for languages.
#   2. `gsac` really puts the fences on their own lines. The `c` surrounding
#      exists only because mini.surround's `?` prompt cannot take newlines, so
#      a left/right pair without the "\n" would silently inline the backticks.
#
# Drives a real nvim for check 2, like tests/nvim-conform.test.sh, and fires
# User VeryLazy by hand for the same reason: lazy.nvim only emits it once a UI
# attaches.
set -u
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

extras_file="$ROOT/home/.config/nvim/lazyvim.json"
assert_contains "$(cat "$extras_file")" "lazyvim.plugins.extras.coding.mini-surround" \
  "mini.surround is no longer enabled in lazyvim.json"

command -v nvim >/dev/null 2>&1 || { echo "skip: nvim not installed"; exit 0; }

data_home="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
[ -d "$data_home/lazy/mini.surround" ] \
  || { echo "skip: mini.surround not cloned yet - open nvim once"; exit 0; }

tmp=$(dotfiles_test_tmproot nvim-surround)
file="$tmp/fence.md"
printf 'before\nfirst\nsecond\nafter\n' > "$file"

ready='lua vim.api.nvim_exec_autocmds("User", {pattern="VeryLazy", modeline=false})
  if not vim.wait(15000, function() return vim.fn.maparg("gsa","x") ~= "" end, 200) then
    vim.cmd("cquit 3")
  end'

XDG_CONFIG_HOME="$ROOT/home/.config" nvim --headless "+e $file" -c "$ready" \
  '+lua vim.fn.feedkeys("2GVjgsac", "x"); vim.wait(5000)' +w +qa >/dev/null 2>&1 \
  || fail "nvim exited non-zero (LazyVim never finished loading?)"

expected=$(printf 'before\n```\nfirst\nsecond\n```\nafter')
[ "$(cat "$file")" = "$expected" ] \
  || fail "gsac did not fence the selection on its own lines: $(cat "$file")"

pass "mini.surround is enabled and gsac wraps a selection in a code fence"
