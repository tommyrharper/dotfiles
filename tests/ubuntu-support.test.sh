#!/usr/bin/env bash
# Ubuntu 22.04 LTS support checks: the Linux homeConfigurations outputs
# evaluate to real derivations, and adding them left the existing
# darwinConfigurations.mac output's evaluated derivation byte-for-byte
# unchanged. The macOS check exists because a past Ubuntu-port attempt
# broke it by editing lines home.nix shares between platforms (the
# gitverify alias, the ai-fill-buffer prompt) without gating them per
# platform - functionally harmless on macOS at runtime, but it still
# changed the evaluated derivation. See tool-selection.nix and home.nix.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

FLAKE_USER=thomasharper

# Pinned at the moment Ubuntu support was layered on top of the tools.nix
# refactor (PR #17, merged as 51fe4b7), then re-pinned after deliberate
# macOS-affecting changes to shared Home Manager zsh initContent, most recently
# when the Hetzner alias changed from root to the configured user, then
# re-pinned again after the fm/dotfiles-ssh-fragment-approach change replaced
# programs.ssh with fragment symlinks + an Include-prepending activation
# script in home.nix, then re-pinned again after adding gnhf (platform =
# "all", updatePolicy = "fast") to tools.nix, which legitimately adds a new
# Homebrew formula to the macOS config, then re-pinned again after adding the
# Linux-only enableSshAgentLinger activation script (home.nix): even though
# its script body is the empty string on Darwin (isDarwin branch), registering
# the activation entry at all still shifts the generated activation script
# text, so the drvPath moves even though nothing runs differently on macOS.
# Re-pinned again after adding installHerdrAgentIntegrations (home.nix): this
# one runs its `herdr integration install` loop identically on both
# platforms (herdr is a platform = "all" tool in tools.nix, and the install
# step behaves the same everywhere), so unlike the Linux-only entries above
# this deliberately changes real macOS activation behavior, not just the
# generated script text. Re-pinned again after uv moved from
# platform = "ubuntu" to platform = "all" in tools.nix, which makes useNix
# select it for macOS too and so legitimately adds pkgs.uv to
# configuration.nix's environment.systemPackages (see
# test_uv_selected_on_both_platforms below).
# Update this only alongside a deliberate macOS-affecting change; an
# unexpected mismatch means something meant to be Linux-only leaked into
# the shared macOS evaluation. Re-pinned again after adding opencode to
# tools.nix - a real new Homebrew formula in homebrew.brews, so this
# legitimately changes darwin-system's derivation too. Re-pinned again after
# adding no-mistakes (platform = "all", updatePolicy = "fast", hasHomebrew =
# false - it has no Homebrew formula at all): tool-selection.nix's
# useHomebrew/useNative now also route a hasHomebrew = false tool through the
# native installer on macOS, so home.nix's installNativeTools activation
# script (previously gated lib.mkIf (!isDarwin)) now runs unconditionally on
# both platforms, and home.sessionPath's ~/.local/bin entry is no longer
# Linux-only either - both legitimately change darwin-system's derivation.
# Re-pinned again after adding treehouse (platform = "all", updatePolicy =
# "fast", default hasHomebrew = true): it adds a real new homebrew-core
# formula to homebrew.brews, and installNativeTools gained a shared
# `mkdir -p "$HOME/.local/bin"` (treehouse's install.sh picks /usr/local/bin +
# sudo when that directory does not exist yet), which runs on both platforms.
# Re-pin again after adding cursor-agent: macOS gets the cursor-cli cask,
# while Linux gets Cursor's official installer and checks for ~/.local/bin/agent.
# Re-pin again after adding prettier (platform = "all", updatePolicy =
# "stable"): a Nix package addition lands in environment.systemPackages on
# macOS too, so the darwin derivation legitimately changes.
# Re-pin again after binding Option+arrow word navigation in the shared zsh
# initContent (home.nix): the bindings are deliberately not platform-gated -
# the bug they fix is a `herdr --remote` pane on Ubuntu, but the same vi
# keymap is selected on macOS, so gating them would leave the two shells
# editing differently. See tests/zsh-word-nav.test.sh.
# Re-pin again after adding the askcursor/chatcursor zsh aliases (home.nix):
# shellAliases is shared, not platform-gated, so a new alias legitimately
# changes the darwin derivation too.
# Re-pin again after turning askcodex from a shellAlias into a function in the
# same shared zsh initContent: `codex exec` writes its banner to stderr and
# only the answer to stdout, and an alias cannot both drop that stderr and
# still take the prompt as an argument. The noise is identical on both
# platforms, so the function is deliberately not gated.
# Re-pin again after adding, then renaming to `ag`, the cursor-agent alias
# (home.nix): shellAliases is shared, not platform-gated, so a new alias
# legitimately changes the darwin derivation too. `cu` was the first name and
# collided with BSD cu(1), the serial dial-out tool already on PATH.
# Re-pin again after adding the `skim` cask to tools.nix: a macOS-only GUI app
# lands in homebrew.casks, so the darwin derivation legitimately changes.
# Re-pin again after adding nixd (platform = "all", updatePolicy = "stable"),
# the Nix language server nvim attaches to .nix buffers: like prettier and uv
# above, a Nix package addition lands in environment.systemPackages on macOS
# too, so the darwin derivation legitimately changes.
# Re-pin again after adding foundry (forge/cast/anvil/chisel) to tools.nix as a
# macOS-only personal tool: it lands in homebrew.brews, so the darwin
# derivation legitimately changes. Ubuntu is untouched - platform = "macos"
# keeps it out of every Linux list.
# Re-pin again after adding spec-kit (platform = "all", updatePolicy = "fast",
# hasHomebrew = false): like no-mistakes it has no Homebrew formula, so it
# joins installNativeTools on macOS as well as Ubuntu, adding a `uv tool
# install specify-cli` block to the shared activation script.
EXPECTED_DARWIN_DRVPATH="/nix/store/c7dv86ifhq3s6prcglhg0km976nfgrnb-darwin-system-26.05.adda04f.drv"

test_darwin_drvpath_unchanged() {
  if ! command -v nix >/dev/null 2>&1; then
    echo "skip: nix not found for darwin drvPath check"
    return 0
  fi
  local drv
  drv=$(cd "$ROOT" && nix eval --raw .#darwinConfigurations.mac.system.drvPath 2>/dev/null) \
    || fail "darwinConfigurations.mac.system.drvPath failed to evaluate"
  [ "$drv" = "$EXPECTED_DARWIN_DRVPATH" ] \
    || fail "darwinConfigurations.mac's evaluated derivation changed (expected $EXPECTED_DARWIN_DRVPATH, got $drv) - Ubuntu support must never change macOS behavior"
  pass "darwinConfigurations.mac.system.drvPath is byte-for-byte unchanged by adding Ubuntu support"
}

test_linux_home_configurations_evaluate() {
  if ! command -v nix >/dev/null 2>&1; then
    echo "skip: nix not found for Linux homeConfigurations check"
    return 0
  fi
  local system drv
  for system in x86_64-linux aarch64-linux; do
    drv=$(cd "$ROOT" && nix eval --raw ".#homeConfigurations.\"${FLAKE_USER}@${system}\".activationPackage.drvPath" 2>/dev/null) \
      || fail "homeConfigurations.\"${FLAKE_USER}@${system}\" failed to evaluate"
    assert_contains "$drv" ".drv" "homeConfigurations.\"${FLAKE_USER}@${system}\" did not evaluate to a real derivation: $drv"
  done
  pass "homeConfigurations for x86_64-linux and aarch64-linux both evaluate to real derivations"
}

test_linux_home_manager_cli_enabled() {
  if ! command -v nix >/dev/null 2>&1; then
    echo "skip: nix not found for Linux home-manager CLI check"
    return 0
  fi
  local system enabled
  for system in x86_64-linux aarch64-linux; do
    enabled=$(cd "$ROOT" && nix eval --json ".#homeConfigurations.\"${FLAKE_USER}@${system}\".config.programs.home-manager.enable" 2>/dev/null) \
      || fail "homeConfigurations.\"${FLAKE_USER}@${system}\" home-manager CLI setting failed to evaluate"
    [ "$enabled" = "true" ] \
      || fail "homeConfigurations.\"${FLAKE_USER}@${system}\" must install the home-manager CLI so ./rebuild.sh works after bootstrap"
  done
  pass "home-manager CLI is installed by both Linux homeConfigurations outputs"
}

test_linux_treesitter_buildtools_present() {
  if ! command -v nix >/dev/null 2>&1; then
    echo "skip: nix not found for Linux build-toolchain check"
    return 0
  fi
  local system names pkg
  for system in x86_64-linux aarch64-linux; do
    names=$(cd "$ROOT" && nix eval --json ".#homeConfigurations.\"${FLAKE_USER}@${system}\".config.home.packages" \
      --apply 'pkgs: map (p: p.pname or p.name) pkgs' 2>/dev/null) \
      || fail "homeConfigurations.\"${FLAKE_USER}@${system}\" home.packages failed to evaluate"
    for pkg in gcc-wrapper gnumake pkg-config-wrapper; do
      assert_contains "$names" "\"$pkg\"" \
        "homeConfigurations.\"${FLAKE_USER}@${system}\" is missing $pkg (needed for nvim-treesitter parser compilation: cc/make/pkg-config)"
    done
  done
  pass "gcc, make, and pkg-config are wired into home.packages for both Linux homeConfigurations outputs"
}

test_linux_nodejs_present_for_npm_backed_native_tools() {
  if ! command -v nix >/dev/null 2>&1; then
    echo "skip: nix not found for Linux nodejs check"
    return 0
  fi
  # skills and pi-coding-agent are npm-backed CLIs: their ~/.local/bin
  # launcher scripts shebang into `node`, so Node must stay on PATH after
  # install too, not just during it (unlike macOS, where the Homebrew
  # formula's own `node` dependency covers this) - see home.nix's home.packages.
  local system names
  for system in x86_64-linux aarch64-linux; do
    names=$(cd "$ROOT" && nix eval --json ".#homeConfigurations.\"${FLAKE_USER}@${system}\".config.home.packages" \
      --apply 'pkgs: map (p: p.pname or p.name) pkgs' 2>/dev/null) \
      || fail "homeConfigurations.\"${FLAKE_USER}@${system}\" home.packages failed to evaluate"
    assert_contains "$names" "\"nodejs\"" \
      "homeConfigurations.\"${FLAKE_USER}@${system}\" is missing nodejs - skills and pi-coding-agent's launchers need node on PATH at runtime, not just during install"
  done
  pass "nodejs is wired into home.packages for both Linux homeConfigurations outputs"
}

test_linux_npm_config_prefix_exported() {
  if ! command -v nix >/dev/null 2>&1; then
    echo "skip: nix not found for NPM_CONFIG_PREFIX check"
    return 0
  fi
  # installNativeTools exports NPM_CONFIG_PREFIX only inside its own
  # activation script, so without this every normal shell still resolves
  # `npm root -g` to the read-only /nix/store nodejs prefix instead of
  # ~/.local/lib/node_modules where skills/gnhf/pi actually live - which is
  # exactly how tests/pi-calm.test.sh ended up silently skipping every
  # sub-check, and why a hand-written (unmanaged) ~/.npmrc was needed on the
  # box. home.sessionVariables lands it in hm-session-vars.sh, which zsh
  # sources from .zshenv, so it holds for every shell after a fresh
  # bootstrap. It must stay Linux-only: macOS gets these tools via Homebrew.
  local system value names
  for system in x86_64-linux aarch64-linux; do
    value=$(cd "$ROOT" && nix eval --raw ".#homeConfigurations.\"${FLAKE_USER}@${system}\".config.home.sessionVariables.NPM_CONFIG_PREFIX" 2>/dev/null) \
      || fail "homeConfigurations.\"${FLAKE_USER}@${system}\" does not set home.sessionVariables.NPM_CONFIG_PREFIX - npm root -g in a normal shell would resolve to the read-only Nix store prefix, not ~/.local"
    [ "$value" = "/home/${FLAKE_USER}/.local" ] \
      || fail "homeConfigurations.\"${FLAKE_USER}@${system}\" NPM_CONFIG_PREFIX must be /home/${FLAKE_USER}/.local to match installNativeTools' own export and home.sessionPath's ~/.local/bin, got: $value"
  done

  names=$(cd "$ROOT" && nix eval --json ".#darwinConfigurations.mac.config.home-manager.users.${FLAKE_USER}.home.sessionVariables" --apply 'builtins.attrNames' 2>/dev/null) \
    || fail "darwinConfigurations.mac home.sessionVariables failed to evaluate"
  assert_not_contains "$names" "NPM_CONFIG_PREFIX" \
    "darwinConfigurations.mac must not get NPM_CONFIG_PREFIX at all - macOS installs these tools via Homebrew. Note home.sessionVariables is a lazyAttrsOf, so gating a leaf attribute with lib.mkIf false leaves it present-but-null here rather than removing it; gate the whole attrset with lib.optionalAttrs instead"
  pass "NPM_CONFIG_PREFIX is exported as ~/.local for both Linux homeConfigurations outputs and entirely absent on darwinConfigurations.mac"
}

test_linux_native_install_tools_wired() {
  if ! command -v nix >/dev/null 2>&1; then
    echo "skip: nix not found for Linux native-install check"
    return 0
  fi
  # Every useNative-selected tools.nix entry that is expected to have a
  # working unattended installer, the real ~/.local/bin binary name each
  # one's installer actually produces (see tools.nix's nativeInstallBinName
  # comment: claude-code's and pi-coding-agent's launcher names differ from
  # their tools.nix entry name), and the exact dry-run line it must print.
  local expected_name_binname="claude-code claude
codex codex
cursor-agent agent
herdr herdr
skills skills
pi-coding-agent pi
gnhf gnhf
opencode opencode
no-mistakes no-mistakes
treehouse treehouse
spec-kit specify"
  local expected_dry_run_lines=(
    "Would install claude-code via https://claude.ai/install.sh"
    "Would install codex via https://chatgpt.com/codex/install.sh"
    "Would install cursor-agent via https://cursor.com/install"
    "Would install herdr via https://herdr.dev/install.sh"
    "Would install skills via npm install -g skills"
    "Would install pi-coding-agent via https://pi.dev/install.sh"
    "Would install gnhf via npm install -g gnhf"
    "Would install opencode via npm install -g opencode-ai"
    "Would install no-mistakes via https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.sh"
    "Would install treehouse via https://kunchenguid.github.io/treehouse/install.sh"
    "Would install spec-kit via uv tool install specify-cli"
  )
  local system selected data tmp_home dry_run_output path_has_local_bin bin_name expect_line
  for system in x86_64-linux aarch64-linux; do
    selected=$(cd "$ROOT" && nix eval --raw --impure --expr "
      let
        flake = builtins.getFlake \"path:$ROOT\";
        pkgs = import flake.inputs.nixpkgs { system = \"$system\"; };
        sel = import $ROOT/tool-selection.nix {
          inherit (pkgs) lib;
          usePersonalSetup = true;
          currentPlatform = \"ubuntu\";
        };
      in pkgs.lib.concatStringsSep \"\n\" (map (t: t.name + \" \" + sel.nativeInstallBinName t) sel.nativeInstallTools)
    " 2>/dev/null) \
      || fail "tool-selection.nix nativeInstallTools failed to evaluate for $system"
    [ "$selected" = "$expected_name_binname" ] \
      || fail "tool-selection.nix nativeInstallTools must contain exactly claude-code, codex, cursor-agent, herdr, skills, pi-coding-agent, gnhf, opencode, no-mistakes, treehouse, and spec-kit's unattended installers (name binName) for $system, got: $selected"

    data=$(cd "$ROOT" && nix eval --raw ".#homeConfigurations.\"${FLAKE_USER}@${system}\".config.home.activation.installNativeTools.data" 2>/dev/null) \
      || fail "homeConfigurations.\"${FLAKE_USER}@${system}\" has no installNativeTools activation script - useNative correctly classifying these tools is not enough, something has to actually install them"

    tmp_home=$(dotfiles_test_tmproot "dotfiles-native-install-$system")
    dry_run_output=$(HOME="$tmp_home" DRY_RUN_CMD=1 bash -eu -o pipefail -c "$data" 2>/dev/null) \
      || fail "homeConfigurations.\"${FLAKE_USER}@${system}\" installNativeTools activation failed in dry-run mode"
    for expect_line in "${expected_dry_run_lines[@]}"; do
      assert_contains "$dry_run_output" "$expect_line" \
        "homeConfigurations.\"${FLAKE_USER}@${system}\" installNativeTools dry-run missing expected line: $expect_line (got: $dry_run_output)"
    done

    path_has_local_bin=$(cd "$ROOT" && nix eval --raw ".#homeConfigurations.\"${FLAKE_USER}@${system}\".config.home.sessionPath" \
      --apply 'p: if builtins.elem "/home/thomasharper/.local/bin" p then "true" else "false"' 2>/dev/null) \
      || fail "homeConfigurations.\"${FLAKE_USER}@${system}\" home.sessionPath failed to evaluate"
    [ "$path_has_local_bin" = "true" ] \
      || fail "homeConfigurations.\"${FLAKE_USER}@${system}\" does not put ~/.local/bin (where every native installer here places its binary) on PATH"

    mkdir -p "$tmp_home/.local/bin"
    for bin_name in claude codex agent herdr skills pi gnhf opencode no-mistakes treehouse specify; do
      touch "$tmp_home/.local/bin/$bin_name"
      chmod +x "$tmp_home/.local/bin/$bin_name"
    done
    dry_run_output=$(HOME="$tmp_home" DRY_RUN_CMD=1 bash -eu -o pipefail -c "$data" 2>/dev/null) \
      || fail "homeConfigurations.\"${FLAKE_USER}@${system}\" installNativeTools activation failed when every tool was already installed"
    [ -z "$dry_run_output" ] \
      || fail "homeConfigurations.\"${FLAKE_USER}@${system}\" installNativeTools must skip every tool already installed under its real binary name, got: $dry_run_output"
  done
  pass "claude-code, codex, cursor-agent, herdr, skills, pi-coding-agent, gnhf, opencode, no-mistakes, treehouse, and spec-kit's native installers are all wired into home.activation, correctly keyed to their real ~/.local/bin binary names, for both Linux homeConfigurations outputs"
}

test_herdr_integrations_run_after_native_install_on_linux() {
  if ! command -v nix >/dev/null 2>&1; then
    echo "skip: nix not found for herdr integration activation order check"
    return 0
  fi
  local system after
  for system in x86_64-linux aarch64-linux; do
    after=$(cd "$ROOT" && nix eval --json ".#homeConfigurations.\"${FLAKE_USER}@${system}\".config.home.activation.installHerdrAgentIntegrations.after" 2>/dev/null) \
      || fail "homeConfigurations.\"${FLAKE_USER}@${system}\" installHerdrAgentIntegrations activation dependencies failed to evaluate"
    assert_contains "$after" "\"installNativeTools\"" \
      "homeConfigurations.\"${FLAKE_USER}@${system}\" must run installHerdrAgentIntegrations after installNativeTools so fresh Ubuntu activations install herdr before installing its agent integrations"
  done
  after=$(cd "$ROOT" && nix eval --json ".#darwinConfigurations.mac.config.home-manager.users.${FLAKE_USER}.home.activation.installHerdrAgentIntegrations.after" 2>/dev/null) \
    || fail "darwinConfigurations.mac installHerdrAgentIntegrations activation dependencies failed to evaluate"
  assert_contains "$after" "\"installNativeTools\"" \
    "darwinConfigurations.mac must also order installHerdrAgentIntegrations after installNativeTools now that entry exists on both platforms (no-mistakes' native install on macOS) - keep the ordering identical on both platforms rather than branching it per OS"
  pass "herdr agent integrations run after native installs on both platforms, with a consistent activation ordering"
}

test_linux_archive_tools_present_for_native_installers() {
  if ! command -v nix >/dev/null 2>&1; then
    echo "skip: nix not found for Linux archive-tools check"
    return 0
  fi
  # codex's own installer hard-requires a `tar` binary to unpack its
  # download ("tar is required to install Codex."), and a genuinely minimal
  # Ubuntu base image can lack one entirely - unlike Docker Hub's
  # ubuntu:22.04, which happens to ship tar and can mask this in testing.
  # gnutar and gzip must be Nix-managed (home.packages) and wired into
  # installNativeTools' own curated PATH export, not just assumed present.
  local current_system system names data gnutar_path gzip_path coreutils_path patched tmp_home empty_path fixture out exit_code ran_archive_check
  current_system=$(nix eval --raw --impure --expr builtins.currentSystem 2>/dev/null) \
    || fail "builtins.currentSystem failed to evaluate"
  ran_archive_check=false
  for system in x86_64-linux aarch64-linux; do
    names=$(cd "$ROOT" && nix eval --json ".#homeConfigurations.\"${FLAKE_USER}@${system}\".config.home.packages" \
      --apply 'pkgs: map (p: p.pname or p.name) pkgs' 2>/dev/null) \
      || fail "homeConfigurations.\"${FLAKE_USER}@${system}\" home.packages failed to evaluate"
    assert_contains "$names" "\"gnutar\"" \
      "homeConfigurations.\"${FLAKE_USER}@${system}\" is missing gnutar - codex's installer requires tar, and a minimal base image may not have one"
    assert_contains "$names" "\"gzip\"" \
      "homeConfigurations.\"${FLAKE_USER}@${system}\" is missing gzip - codex's installer uses tar -xzf, and Nix gnutar shells out to gzip for that"

    data=$(cd "$ROOT" && nix eval --raw ".#homeConfigurations.\"${FLAKE_USER}@${system}\".config.home.activation.installNativeTools.data" 2>/dev/null) \
      || fail "homeConfigurations.\"${FLAKE_USER}@${system}\" installNativeTools activation script failed to evaluate"
    gnutar_path=$(cd "$ROOT" && nix eval --raw --impure --expr "
      let
        flake = builtins.getFlake \"path:$ROOT\";
        pkgs = import flake.inputs.nixpkgs { system = \"$system\"; };
      in pkgs.gnutar
    " 2>/dev/null) \
      || fail "pkgs.gnutar failed to evaluate for $system"
    gzip_path=$(cd "$ROOT" && nix eval --raw --impure --expr "
      let
        flake = builtins.getFlake \"path:$ROOT\";
        pkgs = import flake.inputs.nixpkgs { system = \"$system\"; };
      in pkgs.gzip
    " 2>/dev/null) \
      || fail "pkgs.gzip failed to evaluate for $system"
    coreutils_path=$(cd "$ROOT" && nix eval --raw --impure --expr "
      let
        flake = builtins.getFlake \"path:$ROOT\";
        pkgs = import flake.inputs.nixpkgs { system = \"$system\"; };
      in pkgs.coreutils
    " 2>/dev/null) \
      || fail "pkgs.coreutils failed to evaluate for $system"

    patched=$(printf '%s\n' "$data" \
      | sed -E 's#.*curl -fsSL https://claude\.ai/install\.sh.*#:#' \
      | sed -E "s#.*curl -fsSL https://chatgpt\.com/codex/install\.sh.*#resolved_tar=\\\$(command -v tar) \&\& resolved_gzip=\\\$(command -v gzip) \&\& [ \"\\\$resolved_tar\" = \"$gnutar_path/bin/tar\" ] \&\& [ \"\\\$resolved_gzip\" = \"$gzip_path/bin/gzip\" ] || { echo \"tar/gzip resolved to \\\${resolved_tar:-missing}/\\\${resolved_gzip:-missing}, expected $gnutar_path/bin/tar/$gzip_path/bin/gzip\"; exit 1; }; if [ -n \"\\\${TAR_XZF_FIXTURE:-}\" ]; then mkdir -p \"\\\$HOME/extracted\" \&\& tar -xzf \"\\\$TAR_XZF_FIXTURE\" -C \"\\\$HOME/extracted\" \&\& [ -f \"\\\$HOME/extracted/payload\" ]; fi#" \
      | sed -E 's#.*curl -fsSL https://cursor\.com/install.*#:#' \
      | sed -E 's#.*curl -fsSL https://herdr\.dev/install\.sh.*#:#' \
      | sed -E 's#.*npm install -g skills.*#:#' \
      | sed -E 's#.*curl -fsSL https://pi\.dev/install\.sh.*#:#' \
      | sed -E 's#.*npm install -g gnhf.*#:#')

    if [ "$system" = "$current_system" ]; then
      nix build --no-link "$gnutar_path" "$gzip_path" "$coreutils_path" >/dev/null 2>&1 \
        || fail "failed to realize pkgs.gnutar, pkgs.gzip, and pkgs.coreutils for executable archive-tools check on $system"
      tmp_home=$(dotfiles_test_tmproot "dotfiles-gnutar-path-$system")
      empty_path="$tmp_home/empty-path"
      mkdir -p "$empty_path" "$tmp_home/archive-src"
      printf 'payload\n' > "$tmp_home/archive-src/payload"
      fixture="$tmp_home/payload.tar.gz"
      tar -czf "$fixture" -C "$tmp_home/archive-src" payload \
        || fail "failed to create tar -xzf fixture for $system"
      ran_archive_check=true
      out=$(HOME="$tmp_home" PATH="$empty_path" TAR_XZF_FIXTURE="$fixture" /bin/bash -eu -o pipefail -c "$patched" 2>&1)
      exit_code=$?
      [ "$exit_code" -eq 0 ] \
        || fail "homeConfigurations.\"${FLAKE_USER}@${system}\" installNativeTools must resolve tar/gzip from its own curated PATH as $gnutar_path/bin/tar and $gzip_path/bin/gzip with ambient PATH stripped, and run tar -xzf (exit $exit_code), got: $out"
      assert_not_contains "$out" "WARNING: native install of codex failed" \
        "homeConfigurations.\"${FLAKE_USER}@${system}\" installNativeTools swallowed the tar/gzip check failure instead of proving codex's archive extraction path works, got: $out"
      [ -f "$tmp_home/extracted/payload" ] \
        || fail "homeConfigurations.\"${FLAKE_USER}@${system}\" installNativeTools did not prove tar -xzf extracted the fixture"
    fi
  done
  if [ "$current_system" = "x86_64-linux" ] || [ "$current_system" = "aarch64-linux" ]; then
    [ "$ran_archive_check" = "true" ] \
      || fail "archive extraction check did not run on executable Linux output for current system $current_system"
    pass "gnutar and gzip are Nix-managed for both Linux outputs; installNativeTools' curated PATH resolves and runs tar -xzf on the executable current-system output"
  else
    pass "gnutar and gzip are Nix-managed for both Linux outputs; executable tar -xzf verification is skipped on non-Linux current system $current_system"
  fi
}

test_linux_native_install_fault_isolation() {
  if ! command -v nix >/dev/null 2>&1; then
    echo "skip: nix not found for Linux fault-isolation check"
    return 0
  fi
  # Activation scripts run under set -e: without per-tool isolation, one
  # tool's install failing aborts every later tool in the same
  # concatMapStrings loop before it's ever attempted (this is exactly how
  # codex's real "tar is required" failure also took down herdr, ordered
  # right after it - see AGENTS.md). Replace each tool's real network
  # install command with a deterministic local stand-in (no network needed):
  # codex is forced to fail, and the nearby installer fixtures are forced to succeed.
  # A correct activation script still installs the checked survivors and reports the
  # codex failure loudly instead of aborting silently.
  local system data patched tmp_home out exit_code bin
  for system in x86_64-linux aarch64-linux; do
    data=$(cd "$ROOT" && nix eval --raw ".#homeConfigurations.\"${FLAKE_USER}@${system}\".config.home.activation.installNativeTools.data" 2>/dev/null) \
      || fail "homeConfigurations.\"${FLAKE_USER}@${system}\" installNativeTools activation script failed to evaluate"

    patched=$(printf '%s\n' "$data" \
      | sed -E 's#.*curl -fsSL https://claude\.ai/install\.sh.*#mkdir -p "$HOME/.local/bin" \&\& touch "$HOME/.local/bin/claude" \&\& chmod +x "$HOME/.local/bin/claude"#' \
      | sed -E 's#.*curl -fsSL https://chatgpt\.com/codex/install\.sh.*#false#' \
      | sed -E 's#.*curl -fsSL https://cursor\.com/install.*#mkdir -p "$HOME/.local/bin" \&\& touch "$HOME/.local/bin/agent" \&\& chmod +x "$HOME/.local/bin/agent"#' \
      | sed -E 's#.*curl -fsSL https://herdr\.dev/install\.sh.*#mkdir -p "$HOME/.local/bin" \&\& touch "$HOME/.local/bin/herdr" \&\& chmod +x "$HOME/.local/bin/herdr"#' \
      | sed -E 's#.*npm install -g skills.*#mkdir -p "$HOME/.local/bin" \&\& touch "$HOME/.local/bin/skills" \&\& chmod +x "$HOME/.local/bin/skills"#' \
      | sed -E 's#.*curl -fsSL https://pi\.dev/install\.sh.*#mkdir -p "$HOME/.local/bin" \&\& touch "$HOME/.local/bin/pi" \&\& chmod +x "$HOME/.local/bin/pi"#' \
      | sed -E 's#.*npm install -g gnhf.*#mkdir -p "$HOME/.local/bin" \&\& touch "$HOME/.local/bin/gnhf" \&\& chmod +x "$HOME/.local/bin/gnhf"#')

    tmp_home=$(dotfiles_test_tmproot "dotfiles-fault-isolation-$system")
    out=$(HOME="$tmp_home" bash -eu -o pipefail -c "$patched" 2>&1)
    exit_code=$?
    [ "$exit_code" -eq 0 ] \
      || fail "homeConfigurations.\"${FLAKE_USER}@${system}\" installNativeTools must not hard-fail the whole activation when one tool's install fails (exit $exit_code), got: $out"

    assert_contains "$out" "WARNING: native install of codex failed" \
      "homeConfigurations.\"${FLAKE_USER}@${system}\" installNativeTools must report a failed tool loudly, got: $out"

    [ ! -e "$tmp_home/.local/bin/codex" ] \
      || fail "homeConfigurations.\"${FLAKE_USER}@${system}\" fault-isolation test fixture is broken: codex's forced failure still produced a binary"

    for bin in claude agent herdr skills pi gnhf; do
      [ -x "$tmp_home/.local/bin/$bin" ] \
        || fail "homeConfigurations.\"${FLAKE_USER}@${system}\" installNativeTools must still install $bin when codex's install fails, got: $out"
    done
  done
  pass "installNativeTools isolates each tool's install failure for both Linux homeConfigurations outputs - one broken installer no longer blocks the rest"
}

test_darwin_native_install_only_homebrewless_tools() {
  if ! command -v nix >/dev/null 2>&1; then
    echo "skip: nix not found for Darwin native-install check"
    return 0
  fi
  # installNativeTools now runs on both platforms (no longer gated
  # lib.mkIf (!isDarwin)): no-mistakes and spec-kit have no Homebrew formula
  # at all (hasHomebrew = false in tools.nix), so they are the tools that need
  # the native installer on macOS too. The other nine fast/all tools
  # (claude-code, codex, cursor-agent, herdr, skills, pi-coding-agent,
  # gnhf, opencode, treehouse) must
  # stay exactly where they were - Homebrew-managed on macOS - so this script
  # must mention those two and nothing else.
  local data brews casks names other_marker
  data=$(cd "$ROOT" && nix eval --raw '.#darwinConfigurations.mac.config.home-manager.users.thomasharper.home.activation.installNativeTools.data' 2>/dev/null) \
    || fail "darwinConfigurations.mac has no installNativeTools activation script - no-mistakes (hasHomebrew = false) needs it on macOS too"
  assert_contains "$data" "https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.sh" \
    "darwinConfigurations.mac installNativeTools must install no-mistakes (a Homebrew-less fast/all tool)"
  assert_contains "$data" "uv tool install specify-cli" \
    "darwinConfigurations.mac installNativeTools must install spec-kit (a Homebrew-less fast/all tool) via uv"
  # Distinctive install commands, not bare tool names: every tool's shared
  # per-block comment text mentions "codex" and "pi-coding-agent" by name
  # regardless of which tool the block is actually for (e.g. the
  # CODEX_NON_INTERACTIVE/tar explanation), so a bare-name check would
  # false-positive on no-mistakes' own block.
  for other_marker in \
    "https://claude.ai/install.sh" \
    "https://chatgpt.com/codex/install.sh" \
    "https://cursor.com/install" \
    "https://herdr.dev/install.sh" \
    "npm install -g skills" \
    "https://pi.dev/install.sh" \
    "npm install -g gnhf" \
    "npm install -g opencode-ai" \
    "https://kunchenguid.github.io/treehouse/install.sh"
  do
    assert_not_contains "$data" "$other_marker" \
      "darwinConfigurations.mac installNativeTools must not also try to natively install the tool behind '$other_marker' - it stays Homebrew-managed on macOS"
  done

  brews=$(cd "$ROOT" && nix eval --json '.#darwinConfigurations.mac.config.homebrew.brews' 2>/dev/null) \
    || fail "darwinConfigurations.mac homebrew.brews failed to evaluate"
  casks=$(cd "$ROOT" && nix eval --json '.#darwinConfigurations.mac.config.homebrew.casks' 2>/dev/null) \
    || fail "darwinConfigurations.mac homebrew.casks failed to evaluate"
  assert_not_contains "$brews" "\"no-mistakes\"" \
    "darwinConfigurations.mac must not put no-mistakes in homebrew.brews - it has no Homebrew formula and brew bundle would fail"
  assert_not_contains "$casks" "\"no-mistakes\"" \
    "darwinConfigurations.mac must not put no-mistakes in homebrew.casks either"
  assert_not_contains "$brews" "\"spec-kit\"" \
    "darwinConfigurations.mac must not put spec-kit in homebrew.brews - it has no Homebrew formula and brew bundle would fail"
  assert_not_contains "$casks" "\"spec-kit\"" \
    "darwinConfigurations.mac must not put spec-kit in homebrew.casks either"
  # The mirror image of no-mistakes: treehouse is also a kunchenguid CLI
  # installed from its own install.sh on Ubuntu, but it does have a real
  # homebrew-core formula, so it keeps the default hasHomebrew = true and
  # must land in homebrew.brews on macOS rather than in installNativeTools
  # (asserted above via its install.sh URL in other_marker).
  assert_contains "$brews" "\"treehouse\"" \
    "darwinConfigurations.mac must install treehouse from its real homebrew-core formula, not through the native installer"
  assert_contains "$casks" "\"cursor-cli\"" \
    "darwinConfigurations.mac must install Cursor Agent from the cursor-cli Homebrew cask, not through the native installer"

  names=$(cd "$ROOT" && nix eval --raw '.#darwinConfigurations.mac.config.home-manager.users.thomasharper.home.sessionPath' --apply 'p: if builtins.elem "/Users/thomasharper/.local/bin" p then "true" else "false"' 2>/dev/null) \
    || fail "darwinConfigurations.mac home.sessionPath failed to evaluate"
  [ "$names" = "true" ] \
    || fail "darwinConfigurations.mac must put ~/.local/bin on PATH so a natively-installed no-mistakes is reachable"

  pass "darwinConfigurations.mac's installNativeTools handles only the Homebrew-less tools (no-mistakes, spec-kit); the other nine fast/all tools stay Homebrew-managed, and neither lands in homebrew.brews/casks"
}

test_linux_ssh_agent_persists() {
  if ! command -v nix >/dev/null 2>&1; then
    echo "skip: nix not found for ssh-agent persistence check"
    return 0
  fi
  local system enabled
  for system in x86_64-linux aarch64-linux; do
    enabled=$(cd "$ROOT" && nix eval --json ".#homeConfigurations.\"${FLAKE_USER}@${system}\".config.services.ssh-agent.enable" 2>/dev/null) \
      || fail "homeConfigurations.\"${FLAKE_USER}@${system}\" services.ssh-agent.enable failed to evaluate"
    [ "$enabled" = "true" ] \
      || fail "homeConfigurations.\"${FLAKE_USER}@${system}\" must enable services.ssh-agent so a key added once survives across shells on a minimal Ubuntu server with no gnome-keyring"

    local unit
    unit=$(cd "$ROOT" && nix eval --json ".#homeConfigurations.\"${FLAKE_USER}@${system}\".config.systemd.user.services.ssh-agent.Install.WantedBy" 2>/dev/null) \
      || fail "homeConfigurations.\"${FLAKE_USER}@${system}\" systemd user ssh-agent unit failed to evaluate"
    assert_contains "$unit" "default.target" \
      "homeConfigurations.\"${FLAKE_USER}@${system}\" ssh-agent systemd unit must start on login (WantedBy default.target) to survive across shells"
  done
  pass "services.ssh-agent is enabled with a systemd user unit for both Linux homeConfigurations outputs"
}

test_linux_ssh_agent_lingers_across_sessions() {
  if ! command -v nix >/dev/null 2>&1; then
    echo "skip: nix not found for ssh-agent linger check"
    return 0
  fi
  local system script
  for system in x86_64-linux aarch64-linux; do
    script=$(cd "$ROOT" && nix eval --raw ".#homeConfigurations.\"${FLAKE_USER}@${system}\".config.home.activation.enableSshAgentLinger.data" 2>/dev/null) \
      || fail "homeConfigurations.\"${FLAKE_USER}@${system}\" enableSshAgentLinger activation script failed to evaluate"
    assert_contains "$script" "loginctl enable-linger" \
      "homeConfigurations.\"${FLAKE_USER}@${system}\" must run loginctl enable-linger on activation - without it, systemd-logind kills the ssh-agent systemd --user unit (and any cached key) as soon as the SSH session that ran rebuild closes, so a fresh SSH connection always gets an empty agent"
  done
  pass "enableSshAgentLinger activation script runs loginctl enable-linger for both Linux homeConfigurations outputs"
}

test_darwin_ssh_agent_not_duplicated() {
  if ! command -v nix >/dev/null 2>&1; then
    echo "skip: nix not found for darwin ssh-agent check"
    return 0
  fi
  local enabled
  enabled=$(cd "$ROOT" && nix eval --json ".#darwinConfigurations.mac.config.home-manager.users.${FLAKE_USER}.services.ssh-agent.enable" 2>/dev/null) \
    || fail "darwinConfigurations.mac home-manager services.ssh-agent.enable failed to evaluate"
  [ "$enabled" = "false" ] \
    || fail "darwinConfigurations.mac must leave services.ssh-agent disabled - macOS already gets a persistent agent for free via launchd + Keychain (UseKeychain), enabling it here would run a redundant agent"
  pass "services.ssh-agent stays disabled on darwinConfigurations.mac (macOS already has launchd + Keychain)"
}

# Extracts bootstrap.sh's Linux-only login-shell block (ZSH_BIN=... through its
# closing fi) and runs it against stubbed getent/chsh/sudo, so the guard that
# keeps a non-starting shell out of /etc/passwd is exercised, not just grepped.
run_bootstrap_login_shell_block() {
  local home=$1 current_shell=$2 zsh_runs=$3 log=$4 sudo_ok=${5:-yes} block stub
  block=$(awk '/^  ZSH_BIN=/,/^  fi$/' "$ROOT/bootstrap.sh")
  [ -n "$block" ] || fail "bootstrap.sh no longer contains the ZSH_BIN login-shell block"

  stub="$home/stubs"
  mkdir -p "$stub" "$home/.nix-profile/bin"
  printf '#!/bin/sh\necho "dotfiles-test:x:1000:1000::%s:%s"\n' "$home" "$current_shell" > "$stub/getent"
  printf '#!/bin/sh\nprintf "chsh %%s\\n" "$*" >> "%s"\n' "$log" > "$stub/chsh"
  if [ "$sudo_ok" = yes ]; then
    printf '#!/bin/sh\nprintf "sudo %%s\\n" "$*" >> "%s"\n' "$log" > "$stub/sudo"
  else
    printf '#!/bin/sh\nprintf "sudo %%s\\n" "$*" >> "%s"\necho "sudo: a password is required" >&2\nexit 1\n' "$log" > "$stub/sudo"
  fi
  chmod +x "$stub/getent" "$stub/chsh" "$stub/sudo"

  if [ "$zsh_runs" = yes ]; then
    printf '#!/bin/sh\nexit 0\n' > "$home/.nix-profile/bin/zsh"
  else
    printf '#!/bin/sh\nexit 1\n' > "$home/.nix-profile/bin/zsh"
  fi
  chmod +x "$home/.nix-profile/bin/zsh"

  # bootstrap.sh runs under `set -euo pipefail`, so the block has to be
  # exercised under it too - that is the only way a step that aborts the
  # whole bootstrap is distinguishable from one that warns and carries on.
  HOME="$home" REAL_USER=dotfiles-test PATH="$stub:$PATH" \
    bash -euo pipefail -c "$block" 2>&1
  printf 'exit:%s\n' "$?"
}

test_bootstrap_sets_zsh_login_shell_on_linux() {
  # home.nix enables programs.zsh only, and home-manager's services.ssh-agent
  # module injects SSH_AUTH_SOCK into just the shells it manages. Ubuntu leaves
  # the login shell as /bin/bash, so the agent runs but no shell ever learns
  # its socket and every git pull re-prompts for the key passphrase. bootstrap.sh
  # has to move the login shell to the Nix zsh, or the whole zsh config is dead.
  local home log out

  home=$(dotfiles_test_tmproot dotfiles-login-shell-switch)
  log="$home/calls"
  out=$(run_bootstrap_login_shell_block "$home" /bin/bash yes "$log")
  assert_contains "$(cat "$log" 2>/dev/null)" "chsh -s $home/.nix-profile/bin/zsh dotfiles-test" \
    "bootstrap.sh must chsh a /bin/bash user to the Nix zsh, otherwise SSH_AUTH_SOCK never reaches the login shell (got: $out)"
  assert_contains "$(cat "$log" 2>/dev/null)" "/etc/shells" \
    "bootstrap.sh must add the Nix zsh to /etc/shells first - chsh rejects any shell missing from it (got: $out)"

  # The lockout guard: sshd hands you your login shell and nothing else, so a
  # shell that does not start makes the machine unreachable over SSH.
  home=$(dotfiles_test_tmproot dotfiles-login-shell-broken)
  log="$home/calls"
  out=$(run_bootstrap_login_shell_block "$home" /bin/bash no "$log")
  assert_not_contains "$(cat "$log" 2>/dev/null)" "chsh" \
    "bootstrap.sh must never chsh to a zsh that fails to start - that locks the user out of SSH entirely (got: $out)"
  assert_contains "$out" "leaving the login shell as /bin/bash" \
    "bootstrap.sh must say it left the login shell alone when the Nix zsh does not start (got: $out)"

  # Idempotent: re-running bootstrap.sh on an already-switched box is a no-op.
  home=$(dotfiles_test_tmproot dotfiles-login-shell-noop)
  log="$home/calls"
  out=$(run_bootstrap_login_shell_block "$home" "$home/.nix-profile/bin/zsh" yes "$log")
  assert_not_contains "$(cat "$log" 2>/dev/null)" "chsh" \
    "bootstrap.sh must not re-chsh a user whose login shell is already the Nix zsh (got: $out)"

  # No sudo (or sudo denied) must not abort bootstrap: every earlier step has
  # already succeeded by then, and `set -euo pipefail` would otherwise make a
  # last-step permission failure look like a total bootstrap failure.
  home=$(dotfiles_test_tmproot dotfiles-login-shell-nosudo)
  log="$home/calls"
  out=$(run_bootstrap_login_shell_block "$home" /bin/bash yes "$log" no)
  assert_contains "$out" "exit:0" \
    "bootstrap.sh must not abort under set -e when sudo is unavailable for the login-shell switch (got: $out)"
  assert_contains "$out" "sudo chsh -s $home/.nix-profile/bin/zsh dotfiles-test" \
    "bootstrap.sh must print the exact command to run by hand when it could not switch the login shell itself (got: $out)"
  pass "bootstrap.sh switches the Linux login shell to the Nix zsh, refuses to do so if that zsh will not start, and is a no-op once switched"
}

test_linux_rootless_docker_service() {
  if ! command -v nix >/dev/null 2>&1; then
    echo "skip: nix not found for rootless Docker check"
    return 0
  fi
  # Docker on Linux is a rootless `systemd --user` daemon, not the usual
  # root /var/run/docker.sock one: the ExecStart must be pkgs.docker's own
  # dockerd-rootless (the same package home.packages installs the CLI from,
  # so daemon and client never drift), and DOCKER_HOST has to point the CLI
  # at the per-uid socket it actually listens on, or every `docker` command
  # silently talks to a root socket that isn't there. See README.md
  # ("Rootless Docker").
  local system docker_path exec_start wanted_by docker_host names
  for system in x86_64-linux aarch64-linux; do
    docker_path=$(cd "$ROOT" && nix eval --raw --impure --expr "
      let
        flake = builtins.getFlake \"path:$ROOT\";
        pkgs = import flake.inputs.nixpkgs { system = \"$system\"; };
      in pkgs.docker
    " 2>/dev/null) \
      || fail "pkgs.docker failed to evaluate for $system"

    exec_start=$(cd "$ROOT" && nix eval --raw ".#homeConfigurations.\"${FLAKE_USER}@${system}\".config.systemd.user.services.docker.Service.ExecStart" \
      --apply 'e: if builtins.isList e then builtins.concatStringsSep " " e else e' 2>/dev/null) \
      || fail "homeConfigurations.\"${FLAKE_USER}@${system}\" has no systemd --user docker service - rootless Docker needs a unit, not just the package"
    [ "$exec_start" = "$docker_path/bin/dockerd-rootless" ] \
      || fail "homeConfigurations.\"${FLAKE_USER}@${system}\" docker unit must ExecStart $docker_path/bin/dockerd-rootless (the rootless entry point of the same pkgs.docker home.packages installs), got: $exec_start"

    wanted_by=$(cd "$ROOT" && nix eval --json ".#homeConfigurations.\"${FLAKE_USER}@${system}\".config.systemd.user.services.docker.Install.WantedBy" 2>/dev/null) \
      || fail "homeConfigurations.\"${FLAKE_USER}@${system}\" docker unit has no Install.WantedBy"
    assert_contains "$wanted_by" "default.target" \
      "homeConfigurations.\"${FLAKE_USER}@${system}\" docker unit must start on login (WantedBy default.target); enableSshAgentLinger's loginctl enable-linger is what then keeps it alive between SSH sessions"

    docker_host=$(cd "$ROOT" && nix eval --raw ".#homeConfigurations.\"${FLAKE_USER}@${system}\".config.home.sessionVariables.DOCKER_HOST" 2>/dev/null) \
      || fail "homeConfigurations.\"${FLAKE_USER}@${system}\" does not set DOCKER_HOST - the rootless daemon listens on the per-uid runtime socket and the CLI does not look there by itself"
    [ "$docker_host" = 'unix:///run/user/$(id -u)/docker.sock' ] \
      || fail "homeConfigurations.\"${FLAKE_USER}@${system}\" DOCKER_HOST must be unix:///run/user/\$(id -u)/docker.sock, expanded at hm-session-vars.sh source time so it stays correct for whichever uid the shell runs as, got: $docker_host"

    names=$(cd "$ROOT" && nix eval --json ".#homeConfigurations.\"${FLAKE_USER}@${system}\".config.home.packages" \
      --apply 'pkgs: map (p: p.pname or p.name) pkgs' 2>/dev/null) \
      || fail "homeConfigurations.\"${FLAKE_USER}@${system}\" home.packages failed to evaluate"
    assert_contains "$names" "\"docker\"" \
      "homeConfigurations.\"${FLAKE_USER}@${system}\" is missing the docker CLI that DOCKER_HOST points at"
  done
  pass "both Linux homeConfigurations outputs run pkgs.docker's dockerd-rootless as a systemd --user unit and set DOCKER_HOST to the per-uid socket"
}

test_darwin_rootless_docker_absent() {
  if ! command -v nix >/dev/null 2>&1; then
    echo "skip: nix not found for Darwin rootless Docker absence check"
    return 0
  fi
  # macOS gets Docker from Colima (tools.nix), and has no systemd at all.
  # DOCKER_HOST is checked by attribute name, not value: home.sessionVariables
  # is a lazyAttrsOf, so gating a leaf with `lib.mkIf` leaves the attribute
  # present-but-null here rather than removing it - hence home.nix's
  # lib.optionalAttrs.
  local units session_vars
  units=$(cd "$ROOT" && nix eval --json ".#darwinConfigurations.mac.config.home-manager.users.${FLAKE_USER}.systemd.user.services" \
    --apply 'a: builtins.attrNames a' 2>/dev/null) \
    || fail "darwinConfigurations.mac systemd.user.services failed to evaluate"
  assert_not_contains "$units" "\"docker\"" \
    "darwinConfigurations.mac must not get the Linux-only rootless Docker systemd unit - macOS has no systemd and gets Docker from Colima"

  session_vars=$(cd "$ROOT" && nix eval --json ".#darwinConfigurations.mac.config.home-manager.users.${FLAKE_USER}.home.sessionVariables" \
    --apply 'a: builtins.attrNames a' 2>/dev/null) \
    || fail "darwinConfigurations.mac home.sessionVariables failed to evaluate"
  assert_not_contains "$session_vars" "DOCKER_HOST" \
    "darwinConfigurations.mac must not define DOCKER_HOST at all - Colima writes its own, and a stray null attribute here is exactly what lib.mkIf on a lazyAttrsOf leaf would leave behind"

  pass "darwinConfigurations.mac gets no docker systemd unit and no DOCKER_HOST"
}

test_uv_selected_on_both_platforms() {
  if ! command -v nix >/dev/null 2>&1; then
    echo "skip: nix not found for uv selection check"
    return 0
  fi
  # uv is platform = "all" + updatePolicy = "stable", so tool-selection.nix's
  # useNix claims it on BOTH targets - but they arrive by different routes,
  # and the macOS one is easy to get wrong: home.nix only appends nixTools on
  # its Linux branch, so uv reaches macOS through configuration.nix's
  # environment.systemPackages and is legitimately absent from the macOS
  # home.packages. Asserting that absence would therefore hold no matter how
  # uv were configured and would prove nothing; assert the real route instead.
  local system names darwin_system_pkgs brews casks
  for system in x86_64-linux aarch64-linux; do
    names=$(cd "$ROOT" && nix eval --json ".#homeConfigurations.\"${FLAKE_USER}@${system}\".config.home.packages" \
      --apply 'pkgs: map (p: p.pname or p.name) pkgs' 2>/dev/null) \
      || fail "homeConfigurations.\"${FLAKE_USER}@${system}\" home.packages failed to evaluate"
    assert_contains "$names" "\"uv\"" \
      "homeConfigurations.\"${FLAKE_USER}@${system}\" is missing uv - useNix must select it into the Linux home.packages"
  done

  darwin_system_pkgs=$(cd "$ROOT" && nix eval --json ".#darwinConfigurations.mac.config.environment.systemPackages" \
    --apply 'pkgs: map (p: p.pname or p.name) pkgs' 2>/dev/null) \
    || fail "darwinConfigurations.mac environment.systemPackages failed to evaluate"
  assert_contains "$darwin_system_pkgs" "\"uv\"" \
    "darwinConfigurations.mac is missing uv from environment.systemPackages - that is the only route a platform = \"all\" Nix tool reaches macOS, since home.nix appends nixTools on its Linux branch only"

  # Nix owns it on macOS, not Homebrew: useHomebrew only claims tools that are
  # macOS-specific or fast-moving, so a stray uv here would mean someone
  # changed its platform or updatePolicy rather than just its availability.
  brews=$(cd "$ROOT" && nix eval --json ".#darwinConfigurations.mac.config.homebrew.brews" 2>/dev/null) \
    || fail "darwinConfigurations.mac homebrew.brews failed to evaluate"
  casks=$(cd "$ROOT" && nix eval --json ".#darwinConfigurations.mac.config.homebrew.casks" 2>/dev/null) \
    || fail "darwinConfigurations.mac homebrew.casks failed to evaluate"
  assert_not_contains "$brews" "\"uv\"" \
    "darwinConfigurations.mac must get uv from Nix, not Homebrew - it is updatePolicy = \"stable\" and not macOS-specific"
  assert_not_contains "$casks" "\"uv\"" \
    "darwinConfigurations.mac must not install uv as a Homebrew cask"
  pass "uv is selected by useNix for both platforms - Linux home.packages and macOS environment.systemPackages - and never via Homebrew"
}

# Extracts bootstrap.sh's Linux-only uidmap step (its `if command -v newuidmap`
# through the closing fi) and runs it against a stubbed sudo/newuidmap, so the
# skip and the no-sudo fallback are exercised, not just grepped. PATH is
# replaced outright, never prepended, so `command -v newuidmap` can only ever
# find the stub - the host running these tests very likely has a real one.
run_bootstrap_uidmap_block() {
  local home=$1 newuidmap_present=$2 sudo_ok=$3 log=$4 block stub
  block=$(awk '/^  if command -v newuidmap/,/^  fi$/' "$ROOT/bootstrap.sh")
  [ -n "$block" ] || fail "bootstrap.sh no longer contains the uidmap step"

  stub="$home/stubs"
  mkdir -p "$stub"
  if [ "$sudo_ok" = yes ]; then
    printf '#!/bin/sh\nprintf "sudo %%s\\n" "$*" >> "%s"\n' "$log" > "$stub/sudo"
  else
    printf '#!/bin/sh\nprintf "sudo %%s\\n" "$*" >> "%s"\necho "sudo: a password is required" >&2\nexit 1\n' "$log" > "$stub/sudo"
  fi
  chmod +x "$stub/sudo"
  if [ "$newuidmap_present" = yes ]; then
    printf '#!/bin/sh\nexit 0\n' > "$stub/newuidmap"
    chmod +x "$stub/newuidmap"
  fi

  # bootstrap.sh runs under `set -euo pipefail`, so the block has to be
  # exercised under it too - that is the only way a step that aborts the
  # whole bootstrap is distinguishable from one that warns and carries on.
  # /bin/bash by absolute path: PATH is replaced with the stub dir alone, so
  # a bare `bash` would no longer resolve.
  HOME="$home" PATH="$stub" /bin/bash -euo pipefail -c "$block" 2>&1
  printf 'exit:%s\n' "$?"
}

test_python3_linux_only_for_mason() {
  if ! command -v nix >/dev/null 2>&1; then
    echo "skip: nix not found for python3 selection check"
    return 0
  fi
  # mason installs nvim's basedpyright from PyPI into a venv, which needs a
  # python3 with ensurepip. Ubuntu's system one has none, so Nix supplies it
  # there. macOS already has a working python3 from the Xcode Command Line
  # Tools - the same arrangement as the gcc/gnumake/pkg-config entries above -
  # and adding a Nix python3 to the macOS config would not be harmless: its
  # environment.systemPackages sits ahead of /usr/bin in the PATH, so it would
  # silently shadow the system interpreter on a machine nobody asked to change.
  local system names darwin_system_pkgs
  for system in x86_64-linux aarch64-linux; do
    names=$(cd "$ROOT" && nix eval --json ".#homeConfigurations.\"${FLAKE_USER}@${system}\".config.home.packages" \
      --apply 'pkgs: map (p: p.pname or p.name) pkgs' 2>/dev/null) \
      || fail "homeConfigurations.\"${FLAKE_USER}@${system}\" home.packages failed to evaluate"
    assert_contains "$names" "\"python3\"" \
      "homeConfigurations.\"${FLAKE_USER}@${system}\" is missing python3 - mason cannot install basedpyright without it"
  done

  # Unlike the uv check above, this absence is meaningful: environment.systemPackages
  # is exactly the route a platform = "all" Nix tool takes to macOS, so a python3
  # appearing here is the signal that someone widened the platform field.
  darwin_system_pkgs=$(cd "$ROOT" && nix eval --json ".#darwinConfigurations.mac.config.environment.systemPackages" \
    --apply 'pkgs: map (p: p.pname or p.name) pkgs' 2>/dev/null) \
    || fail "darwinConfigurations.mac environment.systemPackages failed to evaluate"
  assert_not_contains "$darwin_system_pkgs" "\"python3\"" \
    "darwinConfigurations.mac must not install a Nix python3 - macOS has one via Xcode Command Line Tools, and this one would shadow it in PATH"
  pass "python3 is Nix-supplied on Linux for mason and deliberately left to Xcode Command Line Tools on macOS"
}

test_bootstrap_installs_uidmap_on_linux() {
  # home.nix's rootless docker unit needs setuid newuidmap to apply this
  # user's /etc/subuid range, and a Nix store binary can never be setuid - so
  # that one package has to come from apt as root, and cannot move into
  # tools.nix/home.packages. See AGENTS.md and README.md ("Rootless Docker").
  local home log out

  home=$(dotfiles_test_tmproot dotfiles-uidmap-install)
  log="$home/calls"
  out=$(run_bootstrap_uidmap_block "$home" no yes "$log")
  assert_contains "$(cat "$log" 2>/dev/null)" "sudo apt-get install -y uidmap" \
    "bootstrap.sh must apt-get install uidmap when newuidmap is missing - home-manager cannot supply a setuid newuidmap, so the rootless Docker unit dies at startup without it (got: $out)"
  assert_contains "$out" "exit:0" \
    "bootstrap.sh's uidmap step must succeed when sudo works (got: $out)"

  # Idempotent: a box that already has uidmap must not re-run apt-get.
  home=$(dotfiles_test_tmproot dotfiles-uidmap-noop)
  log="$home/calls"
  out=$(run_bootstrap_uidmap_block "$home" yes yes "$log")
  assert_not_contains "$(cat "$log" 2>/dev/null)" "apt-get" \
    "bootstrap.sh must skip the uidmap install when newuidmap is already present (got: $out)"
  assert_contains "$out" "exit:0" \
    "bootstrap.sh's uidmap step must exit cleanly when there is nothing to do (got: $out)"

  # Fault-isolated exactly like the login-shell step: every earlier step has
  # already succeeded by now, so `set -euo pipefail` must not turn a missing
  # or denied sudo into what reads as a total bootstrap failure.
  home=$(dotfiles_test_tmproot dotfiles-uidmap-nosudo)
  log="$home/calls"
  out=$(run_bootstrap_uidmap_block "$home" no no "$log")
  assert_contains "$out" "exit:0" \
    "bootstrap.sh must not abort under set -e when sudo is unavailable for the uidmap install (got: $out)"
  assert_contains "$out" "WARNING" \
    "bootstrap.sh must warn loudly when it could not install uidmap (got: $out)"
  assert_contains "$out" "sudo apt-get install -y uidmap" \
    "bootstrap.sh must print the exact command to run by hand when it could not install uidmap itself (got: $out)"
  pass "bootstrap.sh installs uidmap for rootless Docker, skips it when already present, and warns with the manual command instead of aborting when sudo is unavailable"
}

test_darwin_uidmap_step_absent() {
  # macOS has no apt-get and gets Docker from Colima; the uidmap step must
  # stay inside the Linux branch, which bootstrap.sh's else-branch gives free.
  local darwin_branch
  darwin_branch=$(awk '/^if \[ "\$PLATFORM" = darwin \]; then$/,/^else$/' "$ROOT/bootstrap.sh")
  [ -n "$darwin_branch" ] || fail "bootstrap.sh no longer has a darwin branch to check"
  assert_not_contains "$darwin_branch" "uidmap" \
    "bootstrap.sh must not run the uidmap step on macOS - there is no apt-get, and Docker comes from Colima there"
  pass "bootstrap.sh's macOS branch has no uidmap step"
}

test_darwin_login_shell_untouched() {
  # macOS already logs into zsh; the chsh/sudo step must stay in the Linux
  # branch, which the else-branch structure of bootstrap.sh gives for free.
  local darwin_branch
  darwin_branch=$(awk '/^if \[ "\$PLATFORM" = darwin \]; then$/,/^else$/' "$ROOT/bootstrap.sh")
  [ -n "$darwin_branch" ] || fail "bootstrap.sh no longer has a darwin branch to check"
  assert_not_contains "$darwin_branch" "chsh" \
    "bootstrap.sh must not touch the login shell on macOS - it already logs into zsh"
  pass "bootstrap.sh's macOS branch leaves the login shell alone"
}

test_darwin_drvpath_unchanged
test_linux_home_configurations_evaluate
test_linux_home_manager_cli_enabled
test_linux_treesitter_buildtools_present
test_linux_nodejs_present_for_npm_backed_native_tools
test_linux_npm_config_prefix_exported
test_linux_native_install_tools_wired
test_herdr_integrations_run_after_native_install_on_linux
test_linux_archive_tools_present_for_native_installers
test_linux_native_install_fault_isolation
test_darwin_native_install_only_homebrewless_tools
test_linux_ssh_agent_persists
test_linux_ssh_agent_lingers_across_sessions
test_darwin_ssh_agent_not_duplicated
test_bootstrap_sets_zsh_login_shell_on_linux
test_darwin_login_shell_untouched
test_linux_rootless_docker_service
test_darwin_rootless_docker_absent
test_uv_selected_on_both_platforms
test_python3_linux_only_for_mason
test_bootstrap_installs_uidmap_on_linux
test_darwin_uidmap_step_absent
