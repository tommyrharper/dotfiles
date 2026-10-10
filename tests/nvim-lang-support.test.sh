#!/usr/bin/env bash
# Language support is LazyVim extras, listed in home/.config/nvim/lazyvim.json
# and toggled with :LazyExtras. Two things are worth pinning down:
#
#   1. The set of languages does not silently shrink. `:LazyExtras` rewrites
#      that file wholesale, so a stray toggle is a one-character diff that is
#      easy to miss in review.
#   2. lang.nix needs two things from tools.nix. Its server (`nil`) is a mason
#      package with no prebuilt binary, so mason builds it from source with
#      cargo - drop cargo and Nix support dies with a build error. Its linter
#      (`statix`) mason never installs at all: lang.nix wires it into nvim-lint
#      but, unlike the docker and markdown extras, adds nothing to mason's
#      ensure_installed, so nvim-lint reports "error running statix" on every
#      .nix buffer unless tools.nix supplies it. rust-analyzer is here for the
#      same class of reason: lang.rust mason-installs only the debugger.
#   3. lang.tex is the same shape again: vimtex shells out to a `latexmk` and a
#      viewer it never installs, so the full TeX Live scheme and the Skim cask
#      are load-bearing, as is `tex_flavor` (vimtex attaches to tex, and a
#      preamble-less .tex file is detected as plaintex without it).
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

for lang in docker git json markdown nix python rust tex toml typescript yaml; do
  assert_contains "$extras" "lazyvim.plugins.extras.lang.$lang" \
    "lang.$lang is no longer enabled in lazyvim.json"
done

# lua is deliberately absent: lazydev + lua_ls are LazyVim core, not an extra.
assert_not_contains "$extras" "extras.lang.lua" \
  "lang.lua is not a LazyVim extra; lua support is core"

# The couplings above.
tools=$(cat "$tools_file")
assert_contains "$extras" "extras.lang.nix" "lang.nix is not enabled"
assert_contains "$tools" 'name = "cargo"' \
  "tools.nix no longer declares cargo, so mason cannot build nil for lang.nix"
assert_contains "$tools" 'name = "statix"' \
  "tools.nix no longer declares statix; mason never installs it, so nvim-lint fails on every .nix buffer"
assert_contains "$tools" 'name = "rust-analyzer"' \
  "tools.nix no longer declares rust-analyzer; nothing else installs it for lang.rust"

options=$(cat "$options_file")
assert_contains "$options" 'vim.g.tex_flavor = "latex"' \
  "tex_flavor is no longer set, so a preamble-less .tex file opens as plaintex and vimtex never attaches"
assert_contains "$options" 'vim.g.vimtex_view_method = "skim"' \
  "vimtex no longer points at a viewer, so forward and inverse search are dead"
assert_contains "$tools" 'name = "skim"' \
  "tools.nix no longer declares skim, the viewer vimtex_view_method names"
assert_contains "$(cat "$ROOT/home.nix")" "texlive.combined.scheme-full" \
  "home.nix no longer installs a full TeX Live; vimtex's default latexmk compiler needs it"
[ -r "$ROOT/home/.config/nvim/ftplugin/tex.lua" ] \
  || fail "missing home/.config/nvim/ftplugin/tex.lua; tex buffers lose wrap, spell and conceal"
[ -r "$ROOT/home/.config/nvim/luasnippets/tex.lua" ] \
  || fail "missing home/.config/nvim/luasnippets/tex.lua, the only consumer of the from_lua loader"

# LazyVim defaults format-on-save to on. See tests/nvim-conform.test.sh for the
# behavioural check; this one runs even when plugins are not installed.
assert_contains "$(cat "$options_file")" "vim.g.autoformat = false" \
  "format-on-save is no longer disabled in options.lua"

pass "lazyvim.json enables the expected languages, and tools.nix/home.nix back lang.nix, lang.rust and lang.tex"
