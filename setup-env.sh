#!/usr/bin/env bash
# Reads the setup profile out of the gitignored root .env and turns it into the
# flake output suffix bootstrap.sh and rebuild.sh append. Source it, don't run
# it:
#
#   . "$DIR/setup-env.sh"
#   dotfiles_require_setup_env "$DIR"   # sets DOTFILES_SETUP + DOTFILES_FLAKE_SUFFIX
#
# Why a suffix instead of a value flake.nix reads directly: Nix evaluates this
# repo as a git tree, so an untracked file never reaches the store and
# `builtins.readFile ./.env` would fail to find it. flake.nix therefore exposes
# one output per profile (see its `setups` list) and the choice is made out
# here, where a plain untracked file is readable.

# Fails - loudly, and without touching anything - unless $1/.env names a valid
# setup. Both callers gate on this before any install, symlink, or switch: a
# machine built as the wrong profile is worse than one that refuses to start.
dotfiles_require_setup_env() {
  local dir="$1" env_file value

  env_file="$dir/.env"
  if [ ! -f "$env_file" ]; then
    echo "Missing $env_file - this machine's setup profile has not been chosen." >&2
    echo "  cp $dir/.env.example $dir/.env" >&2
    echo "then set DOTFILES_SETUP to personal or basic and re-run." >&2
    return 1
  fi

  # Read the one key out rather than sourcing the file: .env is hand-edited and
  # both callers run sudo, so an unrelated typo must not execute as shell code.
  # Last assignment wins, the way a shell would resolve it.
  value="$(sed -nE 's/^[[:space:]]*(export[[:space:]]+)?DOTFILES_SETUP=["'\'']?([A-Za-z]*).*/\2/p' "$env_file" | tail -n1)"

  case "$value" in
    personal) DOTFILES_FLAKE_SUFFIX="" ;;
    basic)    DOTFILES_FLAKE_SUFFIX="-basic" ;;
    "")
      echo "DOTFILES_SETUP is not set in $env_file." >&2
      echo "Set it to personal or basic (see $dir/.env.example) and re-run." >&2
      return 1
      ;;
    *)
      echo "DOTFILES_SETUP=$value in $env_file is not a setup this repo builds." >&2
      echo "Use personal or basic (see $dir/.env.example) and re-run." >&2
      return 1
      ;;
  esac

  DOTFILES_SETUP="$value"
  export DOTFILES_SETUP DOTFILES_FLAKE_SUFFIX
}
