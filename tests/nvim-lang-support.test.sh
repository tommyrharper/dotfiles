#!/usr/bin/env bash
# Language support is LazyVim extras, listed in home/.config/nvim/lazyvim.json
# and toggled with :LazyExtras. Two things are worth pinning down:
#
#   1. The set of languages does not silently shrink. `:LazyExtras` rewrites
#      that file wholesale, so a stray toggle is a one-character diff that is
#      easy to miss in review.
#   2. lang.nix only works because tools.nix ships a Rust toolchain. Its server
#      (`nil`) and linter (`statix`) are mason packages with no prebuilt
#      binaries - mason builds both from source with cargo. Drop cargo and Nix
#      support in nvim dies, with a build error rather than a missing-binary
#      one. rust-analyzer is here for the same class of reason: LazyVim's
#      lang.rust extra mason-installs only the debugger, never the server.
#
# Static checks on purpose: no nvim, no network, no plugin install needed.
set -u
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

extras_file="$ROOT/home/.config/nvim/lazyvim.json"
options_file="$ROOT/home/.config/nvim/lua/config/options.lua"
tools_file="$ROOT/tools.nix"

[ -r "$extras_file" ] || fail "missing $extras_file"

extras=$(cat "$extras_file")

for lang in docker git json markdown nix python rust toml typescript yaml; do
  assert_contains "$extras" "lazyvim.plugins.extras.lang.$lang" \
    "lang.$lang is no longer enabled in lazyvim.json"
done

# lua is deliberately absent: lazydev + lua_ls are LazyVim core, not an extra.
assert_not_contains "$extras" "extras.lang.lua" \
  "lang.lua is not a LazyVim extra; lua support is core"

# The coupling above. nil and statix are cargo source builds.
tools=$(cat "$tools_file")
assert_contains "$extras" "extras.lang.nix" "lang.nix is not enabled"
assert_contains "$tools" 'name = "cargo"' \
  "tools.nix no longer declares cargo, so mason cannot build nil/statix for lang.nix"
assert_contains "$tools" 'name = "rust-analyzer"' \
  "tools.nix no longer declares rust-analyzer; nothing else installs it for lang.rust"

# LazyVim defaults format-on-save to on. See tests/nvim-conform.test.sh for the
# behavioural check; this one runs even when plugins are not installed.
assert_contains "$(cat "$options_file")" "vim.g.autoformat = false" \
  "format-on-save is no longer disabled in options.lua"

pass "lazyvim.json enables the expected languages, and tools.nix backs lang.nix/lang.rust"
