#!/usr/bin/env bash
# Covers the zsh alias through the generated Home Manager .zshrc.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if ! command -v nix >/dev/null 2>&1; then
  echo "skip: nix not found for Home Manager zsh evaluation"
  exit 0
fi

if ! command -v zsh >/dev/null 2>&1; then
  echo "skip: zsh not found for shell alias evaluation"
  exit 0
fi

TMP_ROOT=$(dotfiles_test_tmproot hetzner-alias)
TEST_HOME="$TMP_ROOT/home"
ZDOTDIR="$TMP_ROOT/zdotdir"
PRIVATE_DIR="$TEST_HOME/.dotfiles/home/.config/zsh"
PRIVATE_FILE="$PRIVATE_DIR/private-env.zsh"
PLACEHOLDER_HOST="hetzner.example.invalid"

cleanup_private_env() {
  dotfiles_test_cleanup
}
trap cleanup_private_env EXIT

mkdir -p "$TEST_HOME" "$ZDOTDIR" "$PRIVATE_DIR"

# hetzner is now a static shellAliases entry (expanded at invocation time, not
# baked into initContent), so build the actual generated .zshrc rather than
# just evaluating initContent.
zshrc_store_path=$(nix build --no-link --print-out-paths \
  "$ROOT#darwinConfigurations.mac.config.home-manager.users.thomasharper.home.file.\"./.zshrc\".source" \
  2>/dev/null) || fail "could not build generated .zshrc"
cp "$zshrc_store_path" "$ZDOTDIR/.zshrc"

run_hetzner() {
  # Stub ssh so invoking the alias never opens a real connection.
  HOME="$TEST_HOME" ZDOTDIR="$ZDOTDIR" zsh -ic 'ssh() { echo "ssh $*"; }; hetzner' 2>&1
}

rm -f "$PRIVATE_FILE"
actual=$(HETZNER_HOST=ambient.example.invalid run_hetzner)
assert_not_contains "$actual" "ambient.example.invalid" \
  "hetzner alias used an ambient HETZNER_HOST instead of the private env file"
assert_contains "$actual" "HETZNER_HOST not set" \
  "hetzner alias did not report a clear error when the private env file is missing"

printf 'export HETZNER_HOST="%s"\n' "$PLACEHOLDER_HOST" >"$PRIVATE_FILE"
actual=$(run_hetzner)
assert_contains "$actual" "ssh root@$PLACEHOLDER_HOST" \
  "hetzner alias does not use the private host value"

if git -C "$ROOT" ls-files --error-unmatch home/.config/zsh/private-env.zsh >/dev/null 2>&1; then
  fail "private zsh env file is tracked"
fi

pass "hetzner alias is generated from an ignored private zsh env file"
