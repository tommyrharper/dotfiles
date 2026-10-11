#!/usr/bin/env bash
# tdf must show pages inside a herdr pane, and must keep working outside one.
#
# The trap this guards: tdf chooses its image protocol from $TERM_PROGRAM
# before it believes the terminal's own kitty-graphics reply (ratatui-image rev
# 9564ae6 picks `tmux_proto.or(iterm2_proto).or(capability_proto)`, and
# iterm2_proto is Some for any TERM_PROGRAM containing "WezTerm"). A herdr pane
# inherits TERM_PROGRAM=WezTerm from the outer terminal, so tdf emits iTerm2
# inline images; herdr renders only kitty graphics and drops them, leaving the
# chrome and "Rendered: 100%" on screen with every page blank. Verified by
# probing a real pane: herdr answers the kitty query with `_Gi=31;OK`, so
# hiding TERM_PROGRAM is all it takes. Outside herdr the iTerm2 path is the one
# that works, so the wrapper must not touch it.
#
# tdf itself is never run here - a stub stands in that reports the
# TERM_PROGRAM it was given, so this means the same thing on a machine that
# does not have tdf installed.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if ! command -v nix >/dev/null 2>&1; then
  echo "skip: nix not found for Home Manager zsh evaluation"
  exit 0
fi

if ! command -v zsh >/dev/null 2>&1; then
  echo "skip: zsh not found for shell function evaluation"
  exit 0
fi

TMP_ROOT=$(dotfiles_test_tmproot zsh-tdf-herdr)
TEST_HOME="$TMP_ROOT/home"
ZDOTDIR="$TMP_ROOT/zdotdir"
STUB_BIN="$TMP_ROOT/bin"
mkdir -p "$TEST_HOME" "$ZDOTDIR" "$STUB_BIN"

nix eval --impure --raw \
  "$ROOT#darwinConfigurations.mac.config.home-manager.users.${FLAKE_USER}.programs.zsh.initContent" \
  >"$ZDOTDIR/.zshrc"

# Stands in for tdf: reports the TERM_PROGRAM it inherited, which is the whole
# input to tdf's protocol choice, plus its arguments so the wrapper is shown to
# pass them through.
cat >"$STUB_BIN/tdf" <<'EOF'
#!/bin/sh
echo "TERM_PROGRAM=[${TERM_PROGRAM-unset}] args=[$*]"
EOF
chmod +x "$STUB_BIN/tdf"

run_zsh() {
  local herdr_env=$1 cmd=$2
  HOME="$TEST_HOME" ZDOTDIR="$ZDOTDIR" PATH="$STUB_BIN:/usr/bin:/bin" \
    TERM_PROGRAM=WezTerm HERDR_ENV="$herdr_env" zsh -ic "$cmd" 2>/dev/null
}

in_herdr=$(run_zsh 1 'tdf some.pdf')
assert_contains "$in_herdr" "TERM_PROGRAM=[unset]" \
  "inside a herdr pane tdf still sees TERM_PROGRAM, so it emits iTerm2 images that herdr drops and every page renders blank (got: $in_herdr)"
assert_contains "$in_herdr" "args=[some.pdf]" \
  "the tdf wrapper dropped its arguments (got: $in_herdr)"

outside=$(run_zsh "" 'tdf some.pdf')
assert_contains "$outside" "TERM_PROGRAM=[WezTerm]" \
  "outside herdr the wrapper hid TERM_PROGRAM too - WezTerm renders the iTerm2 protocol itself, and suppressing it would switch tdf to a protocol WezTerm handles worse (got: $outside)"

# No tdf, no wrapper function: otherwise the wrapper's `command tdf` turns a
# plain command-not-found into a confusing failure inside env.
no_tdf=$(HOME="$TEST_HOME" ZDOTDIR="$ZDOTDIR" PATH="/usr/bin:/bin" \
  zsh -ic 'whence -w tdf' 2>/dev/null)
assert_not_contains "$no_tdf" function \
  "tdf is wrapped even with tdf absent; the wrapper should only exist when the tool does"

pass "tdf hides TERM_PROGRAM inside herdr only, keeps its arguments, and stays unwrapped without tdf"
