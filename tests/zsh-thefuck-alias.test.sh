#!/usr/bin/env bash
# `fuck` must correct the previous command, and must not cost anything in the
# shells that never call it.
#
# The trap this guards: thefuck installs a `fuck` executable whose only job is
# to print "put eval $(thefuck --alias) in your ~/.zshrc". The real `fuck` is a
# shell function that eval emits, so having the tool on PATH proves nothing -
# this config has to emit it. It does that on first call rather than at startup
# (the eval boots python, ~170ms per shell), which puts a stub function named
# `fuck` in the way: forget to unfunction it before the eval and a missing
# thefuck makes it call itself forever instead of failing.
#
# thefuck itself is never run here - a stub stands in, so the test means the
# same thing on a box that does not have it (it is platform = "macos" in
# tools.nix).
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

TMP_ROOT=$(dotfiles_test_tmproot zsh-thefuck-alias)
TEST_HOME="$TMP_ROOT/home"
ZDOTDIR="$TMP_ROOT/zdotdir"
STUB_BIN="$TMP_ROOT/bin"
mkdir -p "$TEST_HOME" "$ZDOTDIR" "$STUB_BIN"

nix eval --impure --raw \
  "$ROOT#darwinConfigurations.mac.config.home-manager.users.${FLAKE_USER}.programs.zsh.initContent" \
  >"$ZDOTDIR/.zshrc"

# Stands in for `thefuck --alias`, which prints a zsh function definition. The
# marker records that it ran, so the startup-cost check below can tell "never
# called" from "called and quiet".
MARKER="$TMP_ROOT/thefuck-ran"
cat >"$STUB_BIN/thefuck" <<EOF
#!/bin/sh
: > "$MARKER"
echo 'fuck() { echo STUB_CORRECTION; }'
EOF
chmod +x "$STUB_BIN/thefuck"

run_zsh() {
  local path=$1 cmd=$2
  HOME="$TEST_HOME" ZDOTDIR="$ZDOTDIR" PATH="$path" zsh -ic "$cmd" 2>/dev/null
}

WITH_STUB="$STUB_BIN:/usr/bin:/bin"
WITHOUT="/usr/bin:/bin"

assert_contains "$(run_zsh "$WITH_STUB" 'fuck')" STUB_CORRECTION \
  "calling fuck did not run the corrected command; the alias eval never happened"

[ -e "$MARKER" ] || fail "the correction ran but the stub was never called - something else defined fuck"

# Lazy: a shell that never calls fuck must not pay thefuck's python startup.
rm -f "$MARKER"
run_zsh "$WITH_STUB" true >/dev/null
[ -e "$MARKER" ] && fail "thefuck ran at shell startup; every new shell pays its ~170ms python boot"

# No thefuck, no stub function - otherwise the stub calls itself forever.
assert_not_contains "$(run_zsh "$WITHOUT" 'whence -w fuck')" function \
  "fuck is defined with thefuck absent, so calling it recurses into the stub instead of failing"

pass "fuck corrects the previous command, loads lazily, and stays undefined without thefuck"
