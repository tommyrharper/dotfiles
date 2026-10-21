#!/usr/bin/env bash
# update.sh must move the pins, apply them, and upgrade Homebrew - in that
# order, and only on macOS.
#
# The order is the part worth guarding. `nix flake update` has to precede the
# rebuild or the rebuild applies the old pin, and `brew upgrade` has to follow
# it or a tools.nix entry added since the last run is not installed yet and
# gets skipped (brew upgrade only touches what is already present).
#
# Nothing real runs here: nix, brew and rebuild.sh are stubs that append to a
# log, so this proves the sequence on any machine without a 20-minute switch
# or a system mutation. uname is stubbed too, so the Linux branch is covered
# from macOS and vice versa.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TMP_ROOT=$(dotfiles_test_tmproot update-script)
STUB_BIN="$TMP_ROOT/bin"
mkdir -p "$STUB_BIN"

# rebuild.sh has to be a sibling of update.sh: update.sh resolves it from its
# own directory, so the copy needs the same layout rather than the real repo.
FAKE_REPO="$TMP_ROOT/repo"
mkdir -p "$FAKE_REPO"
cp "$ROOT/update.sh" "$FAKE_REPO/update.sh"

LOG="$TMP_ROOT/calls"

for stub in nix brew; do
  cat >"$STUB_BIN/$stub" <<STUB
#!/bin/sh
echo "$stub \$*" >> "$LOG"
STUB
  chmod +x "$STUB_BIN/$stub"
done

cat >"$STUB_BIN/uname" <<STUB
#!/bin/sh
echo "\$DOTFILES_TEST_UNAME"
STUB
chmod +x "$STUB_BIN/uname"

cat >"$FAKE_REPO/rebuild.sh" <<STUB
#!/bin/sh
echo "rebuild" >> "$LOG"
STUB
chmod +x "$FAKE_REPO/rebuild.sh"

run_update() {
  : > "$LOG"
  DOTFILES_TEST_UNAME=$1 PATH="$STUB_BIN:/usr/bin:/bin" bash "$FAKE_REPO/update.sh" \
    || fail "update.sh exited non-zero on $1"
  tr '\n' '|' < "$LOG"
}

# Just the command name per line, so an order check reads as nix|rebuild|brew
# without the temp-directory path the --flake argument carries.
call_order() {
  sed 's/ .*//' "$LOG" | tr '\n' '|'
}

mac=$(run_update Darwin)
mac_order=$(call_order)

assert_contains "$mac" "nix flake update" \
  "update.sh never moved the flake.lock pin, so the rebuild would reapply the old nixpkgs"
assert_contains "$mac" "rebuild" "update.sh never applied the new pins"
assert_contains "$mac" "brew upgrade" \
  "update.sh never ran brew upgrade, so every updatePolicy = fast tool stays stale"

# Exact match, so this fails if any pair is out of order or anything extra ran.
[ "$mac_order" = "nix|rebuild|brew|" ] \
  || fail "update.sh ran the right commands in the wrong order: got $mac_order"

linux=$(run_update Linux)

assert_contains "$linux" "nix flake update" "update.sh skipped the pin bump on Linux"
assert_contains "$linux" "rebuild" "update.sh skipped the rebuild on Linux"
assert_not_contains "$linux" "brew" \
  "update.sh called brew on Linux, where Homebrew is not the installer for anything"

pass "update.sh bumps pins, rebuilds, then upgrades Homebrew on macOS only"
