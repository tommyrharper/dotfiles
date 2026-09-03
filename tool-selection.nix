# Turns ./tools.nix's per-tool metadata into concrete package lists for one
# target. Shared by configuration.nix (currentPlatform = "macos", always) and
# home.nix (currentPlatform derived per Linux homeConfigurations output from
# pkgs.stdenv.hostPlatform) so the three-decision selection logic - is the
# tool enabled, does it apply here, which installer owns it - lives in one
# place instead of drifting between the macOS and Ubuntu paths.
#
# See README.md ("Package metadata") for the full field/selection reference.
{ lib, usePersonalSetup, currentPlatform }:

let
  tools = import ./tools.nix;

  # Decision 1: is the tool wanted on this machine's setup at all?
  isEnabled = t:
    t.scope == "basic" || usePersonalSetup;

  # Decision 2: does the tool apply to the OS we're installing onto?
  isForCurrentPlatform = t:
    t.platform == "all" || t.platform == currentPlatform;

  # Decision 3a: on any OS, a stable "all" package is Nix-managed - it is
  # never macOS/Ubuntu-specific, so nix.enable=false aside, Nix owns it.
  useNix = t:
    isForCurrentPlatform t
    && t.updatePolicy == "stable"
    && t.platform != "macos";

  # Does this tool actually have a Homebrew formula/cask to install? Every
  # entry defaults to true; no-mistakes is the first to set it false (no
  # formula, no tap - see its tools.nix comment), which is what keeps it out
  # of useHomebrew below instead of landing in homebrew.brews as a formula
  # that doesn't exist.
  hasHomebrew = t: t.hasHomebrew or true;

  # Decision 3b: on macOS, tools that apply to macOS use Homebrew when they
  # are either fast-moving or macOS-specific. A platform=all/updatePolicy=fast
  # tool is Homebrew-managed only because currentPlatform is "macos" right
  # now, not because Homebrew is inherently "the" fast-package installer -
  # and only when the tool actually has a Homebrew formula/cask at all.
  useHomebrew = t:
    currentPlatform == "macos"
    && isForCurrentPlatform t
    && (t.platform == "macos" || t.updatePolicy == "fast")
    && hasHomebrew t;

  # Decision 3c: fast-moving tools use a native installer instead of Homebrew
  # wherever Homebrew doesn't own them - always true on Ubuntu (no Homebrew on
  # that path at all), and also true on macOS for the rare tool with no
  # Homebrew formula (hasHomebrew = false), which useHomebrew above excludes.
  useNative = t:
    isForCurrentPlatform t
    && t.updatePolicy == "fast"
    && (currentPlatform == "ubuntu"
        || (currentPlatform == "macos" && !hasHomebrew t));

  isCaskTool = t: t.isCask or false;
  brewName = t: t.brewName or t.name;
  nixName = t: t.nixName or t.name;
  nativeInstallUrl = t: t.nativeInstallUrl or null;
  nativeInstallNpmPackage = t: t.nativeInstallNpmPackage or null;
  nativeInstallUvTool = t: t.nativeInstallUvTool or null;
  nativeInstallBinName = t: t.nativeInstallBinName or t.name;

  enabled = lib.filter isEnabled tools;
  nativeTools = lib.filter useNative enabled;
in
{
  inherit isEnabled isForCurrentPlatform useNix useHomebrew useNative hasHomebrew isCaskTool brewName nixName nativeInstallUrl nativeInstallNpmPackage nativeInstallUvTool nativeInstallBinName;
  nixTools = lib.filter useNix enabled;
  brewTools = lib.filter (t: useHomebrew t && !isCaskTool t) enabled;
  caskTools = lib.filter (t: useHomebrew t && isCaskTool t) enabled;
  inherit nativeTools;
  # Of the useNative-selected tools, only the subset with a working,
  # unattended installer actually wired up - see tools.nix's nativeInstallUrl
  # comment for each tool's non-interactive install path and why it's safe
  # to run unattended from home.activation.
  nativeInstallTools = lib.filter (t: nativeInstallUrl t != null || nativeInstallNpmPackage t != null || nativeInstallUvTool t != null) nativeTools;
}
