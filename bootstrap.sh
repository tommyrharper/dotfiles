#!/usr/bin/env bash
# Takes a fresh machine (macOS or Ubuntu 22.04+) from nothing to a built
# config: nix-darwin on macOS, standalone home-manager on Linux.
# Run this once. After it finishes, use ./rebuild.sh for every later change.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
OS="$(uname -s)"

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
    # BSD sed (macOS) requires the in-place backup suffix as its own arg,
    # even when empty; GNU sed (Linux) takes it attached to -i, or omitted.
    if [ "$OS" = "Darwin" ]; then
      sed -i '' -E "s/^([[:space:]]*user = \")[^\"]+(\";.*)/\1${REAL_USER}\2/" "$DIR/flake.nix"
    else
      sed -i -E "s/^([[:space:]]*user = \")[^\"]+(\";.*)/\1${REAL_USER}\2/" "$DIR/flake.nix"
    fi
    FLAKE_USER="$REAL_USER"
    echo "    Updated. Review the change with: git diff flake.nix"
  else
    echo "    Skipped. Edit the single \"user = \" line in flake.nix yourself before continuing."
    exit 1
  fi
else
  echo "    flake.nix already matches \"$REAL_USER\", nothing to do."
fi

if [ "$OS" = "Darwin" ]; then
  echo "==> Step 4: trust this repo for root"
  # darwin-rebuild always runs via sudo, so root evaluates this flake's
  # git+file:// input. libgit2 refuses to open a repo owned by a different
  # user unless it's allow-listed - add it once, idempotently.
  # -f /etc/gitconfig, not --system: --system resolves per-git-binary and can
  # land in a nix store path a wrapped git considers "system", not the fixed
  # path Nix's own libgit2 fetcher reads.
  sudo git config -f /etc/gitconfig --get-all safe.directory 2>/dev/null | grep -qx "$DIR" \
    || sudo git config -f /etc/gitconfig --add safe.directory "$DIR"

  echo "==> Step 5: first darwin-rebuild switch (pinned to nix-darwin-26.05)"
  # darwin-rebuild doesn't exist yet on a fresh machine, so run it straight
  # from the flake this once. After this, rebuild.sh works normally.
  # This fetches the darwin-rebuild tool from the nix-darwin-26.05 release branch,
  # not the exact flake.lock revision. The system config it applies is still pinned
  # by this repo's flake.lock.
  # sudo resets PATH to a secure default that excludes /nix/.../bin, so a
  # freshly installed `nix` would not be found under sudo even though it's
  # on PATH here. Resolve the absolute path first and invoke that instead.
  NIX_BIN="$(command -v nix)"
  FLAKE_HOST_LABEL="$(sed -nE 's/^[[:space:]]*hostLabel = "([^"]+)";.*/\1/p' "$DIR/flake.nix" | head -n1)"
  if [ -z "$FLAKE_HOST_LABEL" ]; then
    echo "    Could not find the single \"hostLabel = \" line in flake.nix."
    echo "    Edit flake.nix yourself before continuing."
    exit 1
  fi
  sudo "$NIX_BIN" run github:nix-darwin/nix-darwin/nix-darwin-26.05#darwin-rebuild -- \
    switch --flake ~/.dotfiles#"$FLAKE_HOST_LABEL"
  # If this still fails with "nix: command not found", open a new terminal
  # (Determinate adds nix to new shells' PATH) and re-run ./bootstrap.sh.
else
  echo "==> Step 4: detect Linux architecture"
  # flake.nix's homeConfigurations covers x86_64-linux and aarch64-linux;
  # map uname -m onto whichever one matches instead of hardcoding either.
  MACHINE="$(uname -m)"
  case "$MACHINE" in
    x86_64) LINUX_SYSTEM="x86_64-linux" ;;
    aarch64 | arm64) LINUX_SYSTEM="aarch64-linux" ;;
    *)
      echo "    Unrecognized architecture \"$MACHINE\"."
      echo "    Add it to flake.nix's linuxSystems list, then extend this script's case statement to match."
      exit 1
      ;;
  esac
  echo "    $MACHINE -> $LINUX_SYSTEM"

  echo "==> Step 5: first home-manager switch"
  # Standalone home-manager manages only this user's packages and dotfiles,
  # not system config, so it needs no root - the /etc/gitconfig
  # safe.directory trust step above exists only because darwin-rebuild runs
  # via sudo, and doesn't apply here.
  # home-manager doesn't exist yet on a fresh machine, so run it straight
  # from the flake this once, same as darwin-rebuild above. After this,
  # rebuild.sh works normally.
  NIX_BIN="$(command -v nix)"
  "$NIX_BIN" run github:nix-community/home-manager/release-26.05 -- \
    switch --flake ~/.dotfiles#"$FLAKE_USER"@"$LINUX_SYSTEM"
fi

echo "==> Done. Use ./rebuild.sh for future changes."
