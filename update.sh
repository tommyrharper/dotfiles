#!/usr/bin/env bash
# Moves every version pin forward, then applies it.
#
# ./rebuild.sh deliberately does not do this. It builds the nixpkgs revision
# flake.lock already pins and, because configuration.nix leaves
# homebrew.onActivation.upgrade at its default false, runs brew bundle with
# --no-upgrade. That keeps repeated rebuilds reproducible and idempotent.
# Updating is the separate, deliberate act this script performs.
#
# Native-installed tools (tools.nix hasHomebrew = false) are not covered:
# home.nix's installNativeTools skips any tool whose binary already exists, so
# they stay at the version their installer first fetched.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# updatePolicy = "stable" tools come from the pinned nixpkgs, so a newer
# version needs the pin moved before anything is built.
nix flake update --flake "$DIR"

# Before brew upgrade: a tools.nix entry added since the last run is not
# installed yet, and brew upgrade only touches what is already present.
"$DIR/rebuild.sh"

# updatePolicy = "fast" tools on macOS, which Homebrew owns and the rebuild
# above left alone.
if [ "$(uname -s)" = Darwin ]; then
  brew upgrade
fi
