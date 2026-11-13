#!/usr/bin/env bash
# Reads this machine's per-machine settings out of the gitignored root .env:
# the setup profile, which becomes the flake output suffix bootstrap.sh and
# rebuild.sh append, and the username, which they export for flake.nix's
# `builtins.getEnv "DOTFILES_USER"`. Source it, don't run it:
#
#   . "$DIR/setup-env.sh"
#   dotfiles_require_setup_env "$DIR"   # sets DOTFILES_SETUP, BLOCKCHAIN_DEV,
#                                       # DOTFILES_FLAKE_SUFFIX, DOTFILES_USER
#
# Why read .env out here rather than from flake.nix: Nix evaluates this repo as
# a git tree, so an untracked file never reaches the store and
# `builtins.readFile ./.env` would fail to find it. The profile is a closed set,
# so flake.nix exposes one output per combination (see its `setups` list) and
# the choice is made here. A username is not a closed set, so it travels as an
# environment variable instead, and both callers build with --impure.

# Fails - loudly, and without touching anything - unless $1/.env names a valid
# setup. Both callers gate on this before any install, symlink, or switch: a
# machine built as the wrong profile is worse than one that refuses to start.
dotfiles_require_setup_env() {
  local dir="$1" env_file value blockchain username

  env_file="$dir/.env"
  if [ ! -f "$env_file" ]; then
    echo "Missing $env_file - this machine's setup profile has not been chosen." >&2
    echo "  cp $dir/.env.example $dir/.env" >&2
    echo "then set DOTFILES_SETUP to personal or basic (or csd3, see .env.example) and re-run." >&2
    return 1
  fi

  # Read the one key out rather than sourcing the file: .env is hand-edited and
  # both callers run sudo, so an unrelated typo must not execute as shell code.
  # Last assignment wins, the way a shell would resolve it.
  value="$(sed -nE 's/^[[:space:]]*(export[[:space:]]+)?DOTFILES_SETUP=["'\'']?([A-Za-z0-9]*).*/\2/p' "$env_file" | tail -n1)"
  blockchain="$(sed -nE 's/^[[:space:]]*(export[[:space:]]+)?BLOCKCHAIN_DEV=["'\'']?([A-Za-z]*).*/\2/p' "$env_file" | tail -n1)"
  # Captured raw, unlike the two above, then validated below: silently
  # truncating a malformed username at the first odd character would build a
  # home directory for someone who doesn't exist.
  username="$(sed -nE 's/^[[:space:]]*(export[[:space:]]+)?DOTFILES_USER=["'\'']?([^"'\''#]*).*/\2/p' "$env_file" | tail -n1)"
  username="${username%"${username##*[![:space:]]}"}"

  case "$value" in
    personal) DOTFILES_FLAKE_SUFFIX="" ;;
    basic)    DOTFILES_FLAKE_SUFFIX="-basic" ;;
    # basic's tooling for Cambridge's CSD3 cluster: no root, so Nix is
    # nix-portable with its store in ~ and runs only interactive shells
    # (csd3/nix-portable.sh), and nothing needing systemd or sudo is built.
    csd3)     DOTFILES_FLAKE_SUFFIX="-csd3" ;;
    "")
      echo "DOTFILES_SETUP is not set in $env_file." >&2
      echo "Set it to personal or basic, or csd3 (see $dir/.env.example) and re-run." >&2
      return 1
      ;;
    *)
      echo "DOTFILES_SETUP=$value in $env_file is not a setup this repo builds." >&2
      echo "Use personal or basic, or csd3 (see $dir/.env.example) and re-run." >&2
      return 1
      ;;
  esac

  case "${blockchain:-false}" in
    true)  DOTFILES_FLAKE_SUFFIX="$DOTFILES_FLAKE_SUFFIX-blockchain" ;;
    false) ;;
    *)
      echo "BLOCKCHAIN_DEV=$blockchain in $env_file is not valid." >&2
      echo "Use true or false (see $dir/.env.example) and re-run." >&2
      return 1
      ;;
  esac

  # Blank means "whoever is logged in", which is the right answer on almost
  # every machine. Resolve it here, before either caller reaches a sudo call:
  # sudo resets $USER to root, so the real user has to be read first.
  if [ -z "$username" ]; then
    username="$(id -un)"
  fi
  case "$username" in
    *[!A-Za-z0-9._-]*|"")
      echo "DOTFILES_USER=$username in $env_file is not a usable username." >&2
      echo "Use letters, digits, dot, underscore or dash, or leave it blank" >&2
      echo "to use the current login user (see $dir/.env.example)." >&2
      return 1
      ;;
  esac

  DOTFILES_SETUP="$value"
  BLOCKCHAIN_DEV="${blockchain:-false}"
  DOTFILES_USER="$username"
  export DOTFILES_SETUP BLOCKCHAIN_DEV DOTFILES_FLAKE_SUFFIX DOTFILES_USER
}
