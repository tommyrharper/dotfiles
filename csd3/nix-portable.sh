# shellcheck shell=bash
# Nix on Cambridge's CSD3 cluster (DOTFILES_SETUP=csd3). Source it, don't run it.
#
# There is no root there, so no /nix: nix-portable runs Nix inside a user
# namespace (bwrap) with its store in ~/.nix-portable - on /home on purpose.
# Measured on CSD3: a store on Lustre (hpc-work) breaks Nix (lustre.lov
# xattrs it cannot strip, lock EIO, then a hang importing nixpkgs), and the
# node-local disks are neither persistent nor shared between login nodes.
#
# The store only exists inside that namespace, and so does everything
# home-manager links into it (~/.nix-profile, ~/.zshrc, ...). The tools are
# reached by starting the profile's zsh inside it (dotfiles_csd3_shell), which
# dotfiles_csd3_login does for interactive login-node shells. Nothing here ever
# runs inside a Slurm job: CSD3 asks that jobs do no I/O on /home, and a job's
# tools come from modules, containers and hpc-work instead.

DOTFILES_CSD3_NP="${DOTFILES_CSD3_NP:-$HOME/.local/bin/nix-portable}"
# The release this was measured with (Nix 2.20.6 inside).
DOTFILES_CSD3_NP_URL="${DOTFILES_CSD3_NP_URL:-https://github.com/DavHau/nix-portable/releases/download/v012/nix-portable-x86_64}"

dotfiles_csd3_in_job() {
  [ -n "${SLURM_JOB_ID:-}" ]
}

# nix-portable with what CSD3 needs: bwrap (the host has it, and user
# namespaces), and `sandbox = false` - nix-portable turns Nix's build sandbox
# on, and nesting it inside bwrap fails every build with "unable to start
# build process".
dotfiles_csd3_np() {
  if dotfiles_csd3_in_job; then
    echo "dotfiles: nix-portable is for login shells, not Slurm jobs (SLURM_JOB_ID=$SLURM_JOB_ID)" >&2
    return 1
  fi
  NP_LOCATION="${NP_LOCATION:-$HOME}" NP_RUNTIME=bwrap \
    NIX_CONFIG="sandbox = false${NIX_CONFIG:+
$NIX_CONFIG}" "$DOTFILES_CSD3_NP" "$@"
}

dotfiles_csd3_install_np() {
  [ -x "$DOTFILES_CSD3_NP" ] && return 0
  mkdir -p "$(dirname "$DOTFILES_CSD3_NP")"
  curl -fsSL -o "$DOTFILES_CSD3_NP.part" "$DOTFILES_CSD3_NP_URL" \
    && chmod +x "$DOTFILES_CSD3_NP.part" \
    && mv "$DOTFILES_CSD3_NP.part" "$DOTFILES_CSD3_NP"
}

# home-manager from the flake's own locked input, inside the namespace.
#   dotfiles_csd3_home_manager <dotfiles dir> switch --flake ...
dotfiles_csd3_home_manager() {
  local dir="$1"
  shift
  # home-manager needs a profiles directory to exist, which a Determinate
  # install makes and nix-portable does not.
  mkdir -p "$HOME/.local/state/nix/profiles"
  # home-manager shells out to `nix`, which inside the namespace is on no
  # PATH: give it nix-portable's own, the exact version whose store this is
  # (a newer Nix, like the one in the profile, could migrate the store's
  # database past what nix-portable can read). Put on PATH, not in `nix
  # shell`: that store path is unpacked but not registered, and realising
  # it means replacing libraries the running nix has open, which NFS
  # refuses ("Directory not empty").
  local version np_nix
  version="$(dotfiles_csd3_np nix --version)" || return
  version="${version##* }"
  for np_nix in "${NP_LOCATION:-$HOME}"/.nix-portable/nix/store/*-nix-"$version"; do
    [ -x "$np_nix/bin/nix" ] && break
  done
  [ -x "$np_nix/bin/nix" ] \
    || { echo "dotfiles: cannot find nix-portable's own nix $version in its store" >&2; return 1; }
  # shellcheck disable=SC2016  # expanded by the bash inside the namespace
  dotfiles_csd3_np nix shell --inputs-from "$dir" home-manager \
    -c /bin/bash -c 'PATH="$PATH:$1"; shift; exec home-manager "$@"' home-manager \
    "/nix/store/${np_nix##*/}/bin" "$@"
}

# The store path ~/.nix-profile ends at, read link by link: readlink -f
# cannot, because /nix does not exist outside the namespace.
dotfiles_csd3_profile() {
  local path="$HOME/.nix-profile" target _
  for _ in 1 2 3 4 5 6 7 8; do
    target="$(readlink "$path")" || return 1
    case "$target" in
      /*) path="$target" ;;
      *) path="$(dirname "$path")/$target" ;;
    esac
    case "$path" in /nix/store/*) printf '%s\n' "$path"; return 0 ;; esac
  done
  return 1
}

# zsh from the home-manager profile, inside the namespace; arguments go to zsh.
dotfiles_csd3_shell() {
  local profile
  profile="$(dotfiles_csd3_profile)" \
    || { echo "dotfiles: no home-manager profile yet - run ~/.dotfiles/bootstrap.sh" >&2; return 1; }
  # CSD3's cuda module exports FPATH (a Fortran include path); zsh would take
  # it as its function path and lose compinit, is-at-least, add-zsh-hook.
  ( unset FPATH; DOTFILES_CSD3_INSIDE=1 dotfiles_csd3_np nix shell "$profile" -c zsh "$@" )
}

# From ~/.bashrc: an interactive shell on a login node becomes the Nix zsh.
# Never in a Slurm job (sintr included), never twice, never for scp/sftp or
# `ssh host cmd` (not interactive), and not at all while ~/.no-nix-shell
# exists - the way back to plain bash if the store ever breaks. If zsh fails
# to start, bash carries on; once a session has run, leaving zsh leaves bash.
dotfiles_csd3_login() {
  case $- in *i*) ;; *) return 0 ;; esac
  dotfiles_csd3_in_job && return 0
  [ -n "${DOTFILES_CSD3_INSIDE:-}" ] && return 0
  [ -e "$HOME/.no-nix-shell" ] && return 0
  [ -x "$DOTFILES_CSD3_NP" ] || return 0
  dotfiles_csd3_profile >/dev/null || return 0
  local started status
  started=$SECONDS
  dotfiles_csd3_shell -l
  status=$?
  if [ "$status" -eq 0 ] || [ $((SECONDS - started)) -ge 5 ]; then
    exit "$status"
  fi
  echo "dotfiles: the Nix zsh did not start (exit $status); staying in bash." >&2
  echo "          \`touch ~/.no-nix-shell\` skips it until removed." >&2
}
