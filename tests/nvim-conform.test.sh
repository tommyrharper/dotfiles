#!/usr/bin/env bash
# Formatting is on demand, not on save. This drives the real config through a
# real nvim rather than loading the spec, and checks both halves:
#   1. saving a buffer changes nothing, in any filetype
#   2. <leader>F formats the whole buffer with the prettier tools.nix installs
#
# Nothing maps lua or nix on purpose: stylua and nixfmt disagree with this
# repo's own hand-formatting wholesale. See home/.config/nvim/lua/plugins/format.lua.
set -u
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

command -v nvim >/dev/null 2>&1 || { echo "skip: nvim not installed"; exit 0; }
command -v prettier >/dev/null 2>&1 || { echo "skip: prettier not installed"; exit 0; }
[ -d "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy/conform.nvim" ] \
  || { echo "skip: conform.nvim not cloned yet - open nvim once"; exit 0; }

tmp=$(dotfiles_test_tmproot nvim-conform)

# Run nvim against the repo's own config, with the given +commands.
in_nvim() {
  local file=$1; shift
  XDG_CONFIG_HOME="$ROOT/home/.config" nvim --headless "+e $file" "$@" +qa >/dev/null 2>&1
}

two_paragraphs() {
  printf 'first *emphasis*   here\n\nsecond *emphasis*   there\n' > "$1"
}

# 1. A plain write must not touch the buffer - that is the whole point.
two_paragraphs "$tmp/save.md"
cp "$tmp/save.md" "$tmp/save.md.orig"
in_nvim "$tmp/save.md" +w
cmp -s "$tmp/save.md" "$tmp/save.md.orig" \
  || fail "saving reformatted the buffer; formatting is supposed to be on demand"

printf '{ a = 1;   b = 2; }\n' > "$tmp/sample.nix"
cp "$tmp/sample.nix" "$tmp/sample.nix.orig"
in_nvim "$tmp/sample.nix" +w
cmp -s "$tmp/sample.nix" "$tmp/sample.nix.orig" \
  || fail "saving a nix buffer reformatted it; nix is deliberately unmapped"

# 2. The whole buffer, on request. <leader> is a space, so the mapping is " F".
two_paragraphs "$tmp/all.md"
in_nvim "$tmp/all.md" '+lua vim.fn.feedkeys(" F", "x")' +w
grep -q '^first _emphasis_ here$' "$tmp/all.md" \
  || fail "<leader>F did not format the buffer: $(cat "$tmp/all.md")"
grep -q '^second _emphasis_ there$' "$tmp/all.md" \
  || fail "<leader>F formatted only part of the buffer: $(cat "$tmp/all.md")"

pass "conform formats on <leader>F only, never on save"
