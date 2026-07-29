#!/usr/bin/env bash
# Usage: ./rebuild.sh [--basic]
# --basic targets the "basic" host (dev tooling only, no personal casks)
# instead of the personal hostLabel.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ln -sfn "$DIR" ~/.dotfiles

if [ "${1:-}" = "--basic" ]; then
  TARGET_HOST="basic"
else
  TARGET_HOST="$(sed -nE 's/^[[:space:]]*hostLabel = "([^"]+)";.*/\1/p' "$DIR/flake.nix" | head -n1)"
  if [ -z "$TARGET_HOST" ]; then
    echo "Could not find the single \"hostLabel = \" line in flake.nix." >&2
    echo "Edit flake.nix yourself before continuing." >&2
    exit 1
  fi
fi
exec sudo darwin-rebuild switch --flake ~/.dotfiles#"$TARGET_HOST"
