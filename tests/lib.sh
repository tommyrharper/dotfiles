#!/usr/bin/env bash
# tests/lib.sh - shared primitives for dotfiles behavior tests.
#
# Source this from a test file:
#   # shellcheck source=tests/lib.sh
#   . "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
#
# ROOT is exported as the repository root (this file lives in tests/).

if [ -n "${DOTFILES_TEST_LIB_SOURCED:-}" ]; then
  return 0
fi
DOTFILES_TEST_LIB_SOURCED=1

# shellcheck disable=SC2034
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

pass() {
  printf 'ok - %s\n' "$1"
}

# --- self-cleaning temp root -------------------------------------------------

# Callers use tmproot from a command substitution, so it runs in a subshell:
# anything it registers there (an array entry, an EXIT trap) dies with that
# subshell - and an EXIT trap registered inside it fires immediately, deleting
# the directory it just handed back. So the trap is armed here, in the caller's
# own shell, and the list of directories lives in a file both shells can see.
DOTFILES_TEST_CLEANUP_LIST=$(mktemp "${TMPDIR:-/tmp}/dotfiles-test-cleanup.XXXXXX")

dotfiles_test_cleanup() {
  local d
  while IFS= read -r d; do
    [ -n "$d" ] && rm -rf "$d"
  done < "$DOTFILES_TEST_CLEANUP_LIST"
  rm -f "$DOTFILES_TEST_CLEANUP_LIST"
}
trap dotfiles_test_cleanup EXIT

dotfiles_test_tmproot() {
  local prefix=${1:-dotfiles-test} root
  root=$(mktemp -d "${TMPDIR:-/tmp}/${prefix}.XXXXXX")
  printf '%s\n' "$root" >> "$DOTFILES_TEST_CLEANUP_LIST"
  printf '%s\n' "$root"
}

# --- assertions ---------------------------------------------------------------

assert_contains() {
  local haystack=$1 needle=$2 message=$3
  case "$haystack" in
    *"$needle"*) : ;;
    *) fail "$message" ;;
  esac
}

assert_not_contains() {
  local haystack=$1 needle=$2 message=$3
  case "$haystack" in
    *"$needle"*) fail "$message" ;;
    *) : ;;
  esac
}

# --- deterministic git fixtures ------------------------------------------------

dotfiles_git_init_commit() {
  local dir=$1
  mkdir -p "$dir"
  git -C "$dir" init -q
  printf '# %s\n' "$(basename "$dir")" > "$dir/README.md"
  git -C "$dir" add README.md
  git -C "$dir" -c user.name=dotfiles-test -c user.email=dotfiles-test@example.invalid \
    commit -qm "fixture"
}
