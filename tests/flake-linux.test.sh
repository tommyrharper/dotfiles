#!/usr/bin/env bash
# Proves the flake's Linux home-manager outputs evaluate cleanly and that
# adding them left the macOS darwinConfigurations.mac output unchanged.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Baseline drvPath for darwinConfigurations.mac.system, captured before the
# Linux support changes. Must stay byte-identical - any diff means the shared
# home.nix changed macOS's evaluated output.
DARWIN_BASELINE_DRVPATH="/nix/store/ij603ippz2sn5lzw8fhg026icrrcgk78-darwin-system-26.05.adda04f.drv"

test_flake_check() {
  if ! command -v nix >/dev/null 2>&1; then
    echo "skip: nix not found"
    return 0
  fi
  nix flake check --no-build "$ROOT" >/dev/null 2>&1 \
    || fail "nix flake check failed"
  pass "nix flake check passes, including the new Linux homeConfigurations outputs"
}

test_linux_home_configurations_evaluate() {
  local system drv
  if ! command -v nix >/dev/null 2>&1; then
    echo "skip: nix not found"
    return 0
  fi
  for system in x86_64-linux aarch64-linux; do
    drv=$(nix eval --raw "$ROOT#homeConfigurations.thomasharper@${system}.activationPackage.drvPath" 2>/dev/null) \
      || fail "homeConfigurations.thomasharper@${system} did not evaluate"
    assert_contains "$drv" ".drv" "homeConfigurations.thomasharper@${system} did not resolve to a derivation"
  done
  pass "both Linux homeConfigurations outputs (x86_64-linux, aarch64-linux) evaluate to a derivation"
}

test_darwin_output_unaffected() {
  local drv
  if ! command -v nix >/dev/null 2>&1; then
    echo "skip: nix not found"
    return 0
  fi
  drv=$(nix eval --raw "$ROOT#darwinConfigurations.mac.system.drvPath" 2>/dev/null) \
    || fail "darwinConfigurations.mac stopped evaluating"
  [ "$drv" = "$DARWIN_BASELINE_DRVPATH" ] \
    || fail "darwinConfigurations.mac.system.drvPath changed: expected $DARWIN_BASELINE_DRVPATH, got $drv"
  pass "darwinConfigurations.mac.system.drvPath is byte-identical to the pre-Linux baseline"
}

test_flake_check
test_linux_home_configurations_evaluate
test_darwin_output_unaffected
