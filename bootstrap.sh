#!/usr/bin/env bash
# Usage: ./bootstrap.sh [--basic]
# Takes a fresh Mac from nothing to a built nix-darwin config.
# --basic targets the "basic" host (dev tooling only, no personal casks)
# instead of the personal hostLabel - handy for provisioning a second,
# non-personal machine (e.g. a server).
# Run this once. After it finishes, use ./rebuild.sh (or ./rebuild.sh --basic)
# for every later change.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

BASIC=false
REBUILD_SUFFIX=""
if [ "${1:-}" = "--basic" ]; then
  BASIC=true
  REBUILD_SUFFIX=" --basic"
fi

if [ "$BASIC" = true ]; then
  echo "    WARNING: --basic switches this Mac to the \"basic\" darwinConfiguration,"
  echo "    which does not include personalCasks (slack, discord, spotify, notion, figma)."
  echo "    Homebrew cleanup is set to \"zap\", so if this machine currently has those"
  echo "    casks installed under the personal host, they will be uninstalled."
  read -r -p "    Continue with --basic? [y/N] " REPLY
  case "$REPLY" in
    y|Y|yes|YES|Yes) ;;
    *)
      echo "    Aborted."
      exit 1
      ;;
  esac
fi

echo "==> Step 1: Determinate Nix"
if command -v nix >/dev/null 2>&1; then
  echo "    nix already installed, skipping"
else
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install --no-confirm
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

echo "==> Step 2: symlink this repo to ~/.dotfiles"
# home.nix resolves its mkOutOfStoreSymlink paths through ~/.dotfiles, so this
# has to exist before the first switch or the build will fail to find them.
ln -sfn "$DIR" ~/.dotfiles

echo "==> Step 3: personalize the configured username"
# Do this before any sudo call: sudo resets $USER to root, so whoami has to
# run as the real interactive user first.
REAL_USER="$(whoami)"
FLAKE_USER="$(sed -nE 's/^[[:space:]]*user = "([^"]+)";.*/\1/p' "$DIR/flake.nix" | head -n1)"
if [ -z "$FLAKE_USER" ]; then
  echo "    Could not find the single \"user = \" line in flake.nix."
  echo "    Edit flake.nix yourself before continuing."
  exit 1
elif [ "$FLAKE_USER" != "$REAL_USER" ]; then
  echo "    flake.nix is configured for user \"$FLAKE_USER\", but you are \"$REAL_USER\"."
  read -r -p "    Rewrite flake.nix's \"user = \" line to \"$REAL_USER\"? [y/N] " REPLY
  if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ]; then
    sed -i '' -E "s/^([[:space:]]*user = \")[^\"]+(\";.*)/\1${REAL_USER}\2/" "$DIR/flake.nix"
    echo "    Updated. Review the change with: git diff flake.nix"
  else
    echo "    Skipped. Edit the single \"user = \" line in flake.nix yourself before continuing."
    exit 1
  fi
else
  echo "    flake.nix already matches \"$REAL_USER\", nothing to do."
fi

echo "==> Step 4: first darwin-rebuild switch (pinned to nix-darwin-26.05)"
# darwin-rebuild doesn't exist yet on a fresh machine, so run it straight
# from the flake this once. After this, rebuild.sh works normally.
# This fetches the darwin-rebuild tool from the nix-darwin-26.05 release branch,
# not the exact flake.lock revision. The system config it applies is still pinned
# by this repo's flake.lock.
# sudo resets PATH to a secure default that excludes /nix/.../bin, so a
# freshly installed `nix` would not be found under sudo even though it's
# on PATH here. Resolve the absolute path first and invoke that instead.
NIX_BIN="$(command -v nix)"
if [ "$BASIC" = true ]; then
  FLAKE_HOST_LABEL="basic"
else
  FLAKE_HOST_LABEL="$(sed -nE 's/^[[:space:]]*hostLabel = "([^"]+)";.*/\1/p' "$DIR/flake.nix" | head -n1)"
  if [ -z "$FLAKE_HOST_LABEL" ]; then
    echo "    Could not find the single \"hostLabel = \" line in flake.nix."
    echo "    Edit flake.nix yourself before continuing."
    exit 1
  fi
fi
sudo "$NIX_BIN" run github:nix-darwin/nix-darwin/nix-darwin-26.05#darwin-rebuild -- \
  switch --flake ~/.dotfiles#"$FLAKE_HOST_LABEL"
# If this still fails with "nix: command not found", open a new terminal
# (Determinate adds nix to new shells' PATH) and re-run ./bootstrap.sh
# (include --basic again if you passed it originally).

echo "==> Done. Use ./rebuild.sh$REBUILD_SUFFIX for future changes."
