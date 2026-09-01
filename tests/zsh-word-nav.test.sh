#!/usr/bin/env bash
# Option/Alt + Left/Right must move by word in every pane, including the ones
# `herdr --remote` opens on another machine.
#
# The trap this guards: home.sessionVariables sets EDITOR=nvim, and zsh reads
# VISUAL/EDITOR for "vi" at startup to choose its default keymap. That makes
# main viins, where Esc-b and Esc-f are undefined-key - so Esc only leaves
# insert mode (flipping starship's prompt character) and the next letter runs
# as a vi command. Nothing in the terminal config can fix a shell with nothing
# bound, so the bindings have to be here and they have to hold under EDITOR.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if ! command -v nix >/dev/null 2>&1; then
  echo "skip: nix not found for Home Manager zsh evaluation"
  exit 0
fi

if ! command -v zsh >/dev/null 2>&1; then
  echo "skip: zsh not found for shell binding evaluation"
  exit 0
fi

TMP_ROOT=$(dotfiles_test_tmproot zsh-word-nav)
TEST_HOME="$TMP_ROOT/home"
ZDOTDIR="$TMP_ROOT/zdotdir"
mkdir -p "$TEST_HOME" "$ZDOTDIR"

nix eval --raw \
  "$ROOT#darwinConfigurations.mac.config.home-manager.users.thomasharper.programs.zsh.initContent" \
  >"$ZDOTDIR/.zshrc"

# EDITOR is set to the real value on purpose: with it unset zsh picks the emacs
# keymap, where Esc-b/Esc-f are already bound and the test would pass for the
# wrong reason.
lookup() {
  HOME="$TEST_HOME" ZDOTDIR="$ZDOTDIR" EDITOR=nvim zsh -ic "bindkey '$1'" 2>/dev/null
}

# Which keymap `main` resolves to is environment-dependent, and both answers
# are a real shell: "nvim" contains "vi", so zsh picks viins on a box with no
# global rc, while macOS's /etc/zshrc runs `bindkey -e` before any user rc and
# pins emacs there. Pinning one of them here would just re-test zsh's own
# startup rules and fail on the other platform. What Option+arrow actually
# depends on is the four sequences below being bound in whatever `main` is -
# and on emacs, where Esc-b/Esc-f come pre-bound, the CSI pair is the half that
# only this config provides.
keymap=$(HOME="$TEST_HOME" ZDOTDIR="$ZDOTDIR" EDITOR=nvim zsh -ic 'bindkey -lL main' 2>/dev/null)
[ -n "$keymap" ] \
  || fail "could not read the main keymap; zsh did not start with this config, so nothing below is being tested"

# Esc-b/Esc-f is what wezterm.lua sends; CSI 1;3D/1;3C is what a terminal sends
# for a modified arrow when nothing remaps it. Either can arrive, so bind both.
check() {
  local seq=$1 widget=$2 actual
  actual=$(lookup "$seq")
  assert_contains "$actual" "$widget" \
    "$seq is not bound to $widget (got: ${actual:-nothing}); Option+arrow will leave insert mode instead of moving a word"
}

check '^[b' backward-word
check '^[f' forward-word
check '^[[1;3D' backward-word
check '^[[1;3C' forward-word

pass "Option+arrow word navigation is bound in both encodings under EDITOR=nvim"
