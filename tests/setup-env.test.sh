#!/usr/bin/env bash
# setup-env.sh is the gate bootstrap.sh and rebuild.sh both run before they
# touch the machine. Two things have to hold: it refuses every unchosen or
# bogus .env, and the suffix it hands back for a valid one is a flake output
# that actually exists - a suffix nobody built would only fail much later,
# halfway through a switch.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# shellcheck source=setup-env.sh
. "$ROOT/setup-env.sh"

# --- rejection -----------------------------------------------------------------

# $2 is written to .env verbatim; the empty string means "no .env at all".
# $3 is the valid-values hint the rejection must name.
assert_rejected() {
  local label=$1 content=$2 valid=${3:-"personal or basic"} tmp output
  tmp=$(dotfiles_test_tmproot "dotfiles-setup-env")
  if [ -n "$content" ]; then
    printf '%s\n' "$content" > "$tmp/.env"
  fi

  # Subshell: a rejection must not leave DOTFILES_* set for the next case.
  if output=$( (dotfiles_require_setup_env "$tmp") 2>&1 ); then
    fail "setup-env.sh accepted $label - bootstrap.sh/rebuild.sh would build a setup nobody chose"
  fi
  assert_contains "$output" "$valid" \
    "rejecting $label must say which values are valid, got: $output"
}

assert_rejected "a missing .env" ""
assert_rejected "the unedited .env.example" "$(cat "$ROOT/.env.example")"
assert_rejected "an empty DOTFILES_SETUP" "DOTFILES_SETUP="
assert_rejected "an unknown profile" "DOTFILES_SETUP=laptop"
assert_rejected "an .env with no DOTFILES_SETUP line at all" "SOMETHING_ELSE=personal"
assert_rejected "a bogus BLOCKCHAIN_DEV" "$(printf 'DOTFILES_SETUP=basic\nBLOCKCHAIN_DEV=yes')" "true or false"
assert_rejected "a DOTFILES_USER with a space in it" \
  "$(printf 'DOTFILES_SETUP=basic\nDOTFILES_USER=not a user')" "letters, digits"
assert_rejected "a DOTFILES_USER with a slash in it" \
  "$(printf 'DOTFILES_SETUP=basic\nDOTFILES_USER=../etc')" "letters, digits"
pass "setup-env.sh refuses a missing, unset, or unknown .env instead of guessing a profile"

# --- acceptance ----------------------------------------------------------------

assert_accepted() {
  local label=$1 content=$2 expected_suffix=$3 tmp
  tmp=$(dotfiles_test_tmproot "dotfiles-setup-env")
  printf '%s\n' "$content" > "$tmp/.env"

  DOTFILES_SETUP=""
  DOTFILES_FLAKE_SUFFIX="<unset>"
  dotfiles_require_setup_env "$tmp" \
    || fail "setup-env.sh rejected $label, which is a valid .env"
  [ "$DOTFILES_FLAKE_SUFFIX" = "$expected_suffix" ] \
    || fail "$label must select flake output suffix '$expected_suffix', got '$DOTFILES_FLAKE_SUFFIX'"
}

assert_accepted "the personal profile" "DOTFILES_SETUP=personal" ""
assert_accepted "the basic profile" "DOTFILES_SETUP=basic" "-basic"
assert_accepted "a quoted value" 'DOTFILES_SETUP="basic"' "-basic"
assert_accepted "an exported value with a trailing comment" \
  "export DOTFILES_SETUP=basic # server" "-basic"
assert_accepted "the unedited example's BLOCKCHAIN_DEV=false" \
  "$(printf 'DOTFILES_SETUP=basic\nBLOCKCHAIN_DEV=false')" "-basic"
assert_accepted "personal with blockchain dev" \
  "$(printf 'DOTFILES_SETUP=personal\nBLOCKCHAIN_DEV=true')" "-blockchain"
assert_accepted "basic with blockchain dev" \
  "$(printf 'DOTFILES_SETUP=basic\nBLOCKCHAIN_DEV=true')" "-basic-blockchain"
pass "setup-env.sh maps DOTFILES_SETUP and BLOCKCHAIN_DEV onto the flake output suffixes"

# --- the username ----------------------------------------------------------------

# flake.nix has no username in it any more: it reads DOTFILES_USER out of the
# environment, and this is what puts it there.
assert_user() {
  local label=$1 content=$2 expected=$3 tmp
  tmp=$(dotfiles_test_tmproot "dotfiles-setup-env")
  printf '%s\n' "$content" > "$tmp/.env"

  DOTFILES_USER="<unset>"
  dotfiles_require_setup_env "$tmp" \
    || fail "setup-env.sh rejected $label, which is a valid .env"
  [ "$DOTFILES_USER" = "$expected" ] \
    || fail "$label must resolve DOTFILES_USER to '$expected', got '$DOTFILES_USER'"
}

assert_user "an explicit username" \
  "$(printf 'DOTFILES_SETUP=basic\nDOTFILES_USER=someone.else')" "someone.else"
assert_user "a quoted, exported username with a trailing comment" \
  "$(printf 'DOTFILES_SETUP=basic\nexport DOTFILES_USER="someone-else" # the server account')" "someone-else"
assert_user "a blank DOTFILES_USER" \
  "$(printf 'DOTFILES_SETUP=basic\nDOTFILES_USER=')" "$(id -un)"
assert_user "an .env with no DOTFILES_USER line at all" "DOTFILES_SETUP=basic" "$(id -un)"
pass "setup-env.sh resolves DOTFILES_USER from .env, falling back to the login user"

# --- the gate is wired into both entry points ------------------------------------

# The helper being correct is only half of it: bootstrap.sh and rebuild.sh have
# to consult it before they install, symlink, or switch anything. Run them for
# real against a copy with no .env, with every mutating command stubbed out so
# that a regression here fails the assertion instead of the machine.
stubbed_run() {
  local script=$1 tmp stub name
  tmp=$(dotfiles_test_tmproot "dotfiles-setup-env-gate")
  cp "$ROOT/bootstrap.sh" "$ROOT/rebuild.sh" "$ROOT/setup-env.sh" "$ROOT/.env.example" "$tmp/"

  stub="$tmp/stubbin"
  mkdir -p "$stub" "$tmp/home"
  for name in ln sudo nix curl darwin-rebuild home-manager git chsh apt-get; do
    printf '#!/bin/sh\necho "STUB %s $*"\nexit 0\n' "$name" > "$stub/$name"
    chmod +x "$stub/$name"
  done

  HOME="$tmp/home" PATH="$stub:$PATH" bash "$tmp/$script" 2>&1
}

for script in bootstrap.sh rebuild.sh; do
  if output=$(stubbed_run "$script"); then
    fail "$script ran to completion with no .env - it must refuse before touching the machine (got: $output)"
  fi
  assert_contains "$output" ".env" \
    "$script must say which file is missing when the setup profile is unchosen, got: $output"
  assert_not_contains "$output" "STUB" \
    "$script reached a real command before the .env gate - nothing may run before the profile is known (got: $output)"
done
pass "bootstrap.sh and rebuild.sh both refuse to do anything until .env names a setup"

# --- the suffixes name real flake outputs ---------------------------------------

if ! command -v nix >/dev/null 2>&1; then
  echo "skip: nix not found for flake output check"
  exit 0
fi

# The acceptance cases above ran dotfiles_require_setup_env against fixture
# .env files, which overwrote the exported DOTFILES_USER. Put the test-wide one
# back, since it is what the evaluations below name their outputs after.
export DOTFILES_USER="$FLAKE_USER"
HOST_LABEL="$(sed -nE 's/^[[:space:]]*hostLabel = "([^"]+)";.*/\1/p' "$ROOT/flake.nix" | head -n1)"

darwin_outputs=$(cd "$ROOT" && nix eval --impure --json .#darwinConfigurations --apply builtins.attrNames 2>/dev/null) \
  || fail "darwinConfigurations failed to evaluate"
home_outputs=$(cd "$ROOT" && nix eval --impure --json .#homeConfigurations --apply builtins.attrNames 2>/dev/null) \
  || fail "homeConfigurations failed to evaluate"

for suffix in "" "-basic" "-blockchain" "-basic-blockchain"; do
  assert_contains "$darwin_outputs" "\"${HOST_LABEL}${suffix}\"" \
    "flake.nix has no darwinConfigurations.${HOST_LABEL}${suffix} - rebuild.sh builds that name for one of the two .env profiles, got: $darwin_outputs"
  for system in x86_64-linux aarch64-linux; do
    assert_contains "$home_outputs" "\"${FLAKE_USER}@${system}${suffix}\"" \
      "flake.nix has no homeConfigurations.\"${FLAKE_USER}@${system}${suffix}\" - rebuild.sh builds that name for one of the two .env profiles, got: $home_outputs"
  done
done
pass "every suffix setup-env.sh can return names a real darwin and Linux flake output"

# The username has to come from the environment, not from a tracked file:
# a second, different DOTFILES_USER must move home.username with it.
other_user=$(cd "$ROOT" && DOTFILES_USER=someone-else nix eval --impure --raw \
  '.#darwinConfigurations.mac.config.home-manager.users.someone-else.home.username' 2>/dev/null) \
  || fail "flake.nix did not build for DOTFILES_USER=someone-else - the username is not coming from the environment"
[ "$other_user" = "someone-else" ] \
  || fail "home.username is '$other_user', not the DOTFILES_USER the build was given"
pass "flake.nix takes its username from DOTFILES_USER, so no tracked file names the account"

# The suffix has to change what gets installed, not just the output name:
# personal casks are the visible half of the difference on macOS.
personal_casks=$(cd "$ROOT" && nix eval --impure --json ".#darwinConfigurations.${HOST_LABEL}.config.homebrew.casks" 2>/dev/null) \
  || fail "darwinConfigurations.${HOST_LABEL} homebrew.casks failed to evaluate"
basic_casks=$(cd "$ROOT" && nix eval --impure --json ".#darwinConfigurations.${HOST_LABEL}-basic.config.homebrew.casks" 2>/dev/null) \
  || fail "darwinConfigurations.${HOST_LABEL}-basic homebrew.casks failed to evaluate"

assert_contains "$personal_casks" '"slack"' \
  "the personal output must still install scope=personal casks, got: $personal_casks"
assert_not_contains "$basic_casks" '"slack"' \
  "DOTFILES_SETUP=basic must drop scope=personal casks, got: $basic_casks"
pass "the -basic output really is usePersonalSetup = false (no personal casks)"

# Same for the blockchain toggle: foundry is Nix-managed on macOS, so it shows
# up in environment.systemPackages only when the suffix asks for it.
system_package_names() {
  (cd "$ROOT" && nix eval --impure --json ".#darwinConfigurations.${HOST_LABEL}$1.config.environment.systemPackages" \
    --apply 'map (p: p.pname or p.name)' 2>/dev/null) \
    || fail "darwinConfigurations.${HOST_LABEL}$1 environment.systemPackages failed to evaluate"
}
assert_contains "$(system_package_names -blockchain)" '"foundry"' \
  "the -blockchain output must install scope=blockchain tools"
assert_not_contains "$(system_package_names "")" '"foundry"' \
  "BLOCKCHAIN_DEV=false (the default) must drop scope=blockchain tools"
pass "the -blockchain output really is blockchainDev = true (foundry present)"
