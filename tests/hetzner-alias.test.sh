#!/usr/bin/env bash
# Covers the zsh alias through the generated Home Manager startup script.
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
STUB_BIN="$TMP_ROOT/bin"
PLACEHOLDER_HOST="hetzner.example.invalid"

cleanup_private_env() {
  dotfiles_test_cleanup
}
trap cleanup_private_env EXIT

mkdir -p "$TEST_HOME" "$ZDOTDIR" "$PRIVATE_DIR" "$STUB_BIN"

# Stub out ssh so the test never dials a real host - it just records the
# argv it was called with.
cat >"$STUB_BIN/ssh" <<'EOF'
#!/usr/bin/env bash
echo "ssh-stub-called: $*"
EOF
chmod +x "$STUB_BIN/ssh"

render_zshrc() {
  nix eval --raw \
    "$ROOT#darwinConfigurations.mac.config.home-manager.users.thomasharper.home.file.\"./.zshrc\".text" \
    >"$ZDOTDIR/.zshrc"
}

# The alias is now static (always defined), so behavior is verified by
# running it rather than by checking whether `alias hetzner` exists.
run_hetzner() {
  HOME="$TEST_HOME" ZDOTDIR="$ZDOTDIR" PATH="$STUB_BIN:$PATH" zsh -ic 'hetzner' 2>&1
}

rm -f "$PRIVATE_FILE"
render_zshrc
actual=$(HETZNER_HOST=ambient.example.invalid run_hetzner)
assert_contains "$actual" "not set" "hetzner does not report the missing private host"
if [[ "$actual" == *"ssh-stub-called"* ]]; then
  fail "hetzner called ssh when no private env file is present, got: $actual"
fi

printf 'export HETZNER_HOST="%s"\n' "$PLACEHOLDER_HOST" >"$PRIVATE_FILE"
render_zshrc
actual=$(run_hetzner)
assert_contains "$actual" "ssh-stub-called: root@$PLACEHOLDER_HOST" "hetzner does not ssh to the private host value"

# A later ambient export must not override the value captured at shell start.
actual_override=$(HETZNER_HOST=ambient.example.invalid HOME="$TEST_HOME" ZDOTDIR="$ZDOTDIR" PATH="$STUB_BIN:$PATH" zsh -ic 'export HETZNER_HOST=later.example.invalid; hetzner' 2>&1)
if [[ "$actual_override" == *"later.example.invalid"* ]]; then
  fail "hetzner used a later ambient HETZNER_HOST override instead of the captured private value"
fi
assert_contains "$actual_override" "ssh-stub-called: root@$PLACEHOLDER_HOST" "hetzner did not keep using the captured private host after an ambient override"

if git -C "$ROOT" ls-files --error-unmatch home/.config/zsh/private-env.zsh >/dev/null 2>&1; then
  fail "private zsh env file is tracked"
fi

pass "hetzner alias is generated from an ignored private zsh env file"
