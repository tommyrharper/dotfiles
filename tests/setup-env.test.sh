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
assert_rejected() {
  local label=$1 content=$2 tmp output
  tmp=$(dotfiles_test_tmproot "dotfiles-setup-env")
  if [ -n "$content" ]; then
    printf '%s\n' "$content" > "$tmp/.env"
  fi

  # Subshell: a rejection must not leave DOTFILES_* set for the next case.
  if output=$( (dotfiles_require_setup_env "$tmp") 2>&1 ); then
    fail "setup-env.sh accepted $label - bootstrap.sh/rebuild.sh would build a setup nobody chose"
  fi
  assert_contains "$output" "personal or basic" \
    "rejecting $label must say which values are valid, got: $output"
}

assert_rejected "a missing .env" ""
assert_rejected "the unedited .env.example" "$(cat "$ROOT/.env.example")"
assert_rejected "an empty DOTFILES_SETUP" "DOTFILES_SETUP="
assert_rejected "an unknown profile" "DOTFILES_SETUP=laptop"
assert_rejected "an .env with no DOTFILES_SETUP line at all" "SOMETHING_ELSE=personal"
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
pass "setup-env.sh maps personal/basic onto the '' and '-basic' flake output suffixes"

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

FLAKE_USER="$(sed -nE 's/^[[:space:]]*user = "([^"]+)";.*/\1/p' "$ROOT/flake.nix" | head -n1)"
HOST_LABEL="$(sed -nE 's/^[[:space:]]*hostLabel = "([^"]+)";.*/\1/p' "$ROOT/flake.nix" | head -n1)"

darwin_outputs=$(cd "$ROOT" && nix eval --json .#darwinConfigurations --apply builtins.attrNames 2>/dev/null) \
  || fail "darwinConfigurations failed to evaluate"
home_outputs=$(cd "$ROOT" && nix eval --json .#homeConfigurations --apply builtins.attrNames 2>/dev/null) \
  || fail "homeConfigurations failed to evaluate"

for suffix in "" "-basic"; do
  assert_contains "$darwin_outputs" "\"${HOST_LABEL}${suffix}\"" \
    "flake.nix has no darwinConfigurations.${HOST_LABEL}${suffix} - rebuild.sh builds that name for one of the two .env profiles, got: $darwin_outputs"
  for system in x86_64-linux aarch64-linux; do
    assert_contains "$home_outputs" "\"${FLAKE_USER}@${system}${suffix}\"" \
      "flake.nix has no homeConfigurations.\"${FLAKE_USER}@${system}${suffix}\" - rebuild.sh builds that name for one of the two .env profiles, got: $home_outputs"
  done
done
pass "every suffix setup-env.sh can return names a real darwin and Linux flake output"

# The suffix has to change what gets installed, not just the output name:
# personal casks are the visible half of the difference on macOS.
personal_casks=$(cd "$ROOT" && nix eval --json ".#darwinConfigurations.${HOST_LABEL}.config.homebrew.casks" 2>/dev/null) \
  || fail "darwinConfigurations.${HOST_LABEL} homebrew.casks failed to evaluate"
basic_casks=$(cd "$ROOT" && nix eval --json ".#darwinConfigurations.${HOST_LABEL}-basic.config.homebrew.casks" 2>/dev/null) \
  || fail "darwinConfigurations.${HOST_LABEL}-basic homebrew.casks failed to evaluate"

assert_contains "$personal_casks" '"slack"' \
  "the personal output must still install scope=personal casks, got: $personal_casks"
assert_not_contains "$basic_casks" '"slack"' \
  "DOTFILES_SETUP=basic must drop scope=personal casks, got: $basic_casks"
pass "the -basic output really is usePersonalSetup = false (no personal casks)"
