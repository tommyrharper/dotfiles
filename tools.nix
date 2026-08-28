# Single source of truth for CLI/GUI tool metadata, shared by macOS
# (Homebrew + Nix) and Ubuntu (Nix + native installers).
#
# Field reference and selection-logic docs: README.md ("Package metadata").
# Selection logic that reads this table lives in ./tool-selection.nix,
# consumed by configuration.nix (macOS) and home.nix (Ubuntu).
[
  # Fast-moving CLI agents wanted on every machine - track upstream closely,
  # so Homebrew rather than a pinned nixpkgs version.
  # nativeInstallUrl: each of these ships an official installer script that is
  # non-interactive and checksum-/registry-verified when no /dev/tty is
  # attached (confirmed by running each live in a clean Ubuntu 22.04
  # container - see tool-selection.nix's nativeInstallUrl helper and
  # home.nix's installNativeTools activation script for how CODEX_NON_INTERACTIVE,
  # NPM_CONFIG_PREFIX, and the pre-populated ~/.local/bin PATH keep all of
  # these out of shell-rc-mutation branches):
  # - claude-code: claude.ai/install.sh drops straight to ~/.local/bin/claude
  #   with no prompts and no rc edits, tty or not.
  # - codex: chatgpt.com/codex/install.sh only rewrites a shell profile when
  #   its target bin dir isn't already on $PATH; CODEX_NON_INTERACTIVE=1 also
  #   skips its "start now?"/uninstall-conflict prompts.
  # - cursor-agent: cursor.com/install drops the `agent` launcher into
  #   ~/.local/bin and relies on that directory being on PATH, which this
  #   activation script already guarantees.
  # - pi-coding-agent: pi.dev/install.sh only prompts to install Node.js
  #   itself when Node isn't already on $PATH; with pkgs.nodejs present it
  #   detects no tty and proceeds via plain `npm install -g`.
  # nativeInstallBinName: the launcher binary these two installers actually
  # produce in ~/.local/bin differs from the tools.nix entry name (upstream
  # naming, not ours) - home.nix's "already installed" skip check needs the
  # real binary name or it would re-run the installer on every rebuild.
  { name = "claude-code"; scope = "basic"; platform = "all"; updatePolicy = "fast"; isCask = true; nativeInstallUrl = "https://claude.ai/install.sh"; nativeInstallBinName = "claude"; }
  { name = "codex"; scope = "basic"; platform = "all"; updatePolicy = "fast"; isCask = true; nativeInstallUrl = "https://chatgpt.com/codex/install.sh"; }
  { name = "cursor-agent"; scope = "basic"; platform = "all"; updatePolicy = "fast"; isCask = true; brewName = "cursor-cli"; nativeInstallUrl = "https://cursor.com/install"; nativeInstallBinName = "agent"; }
  { name = "herdr"; scope = "basic"; platform = "all"; updatePolicy = "fast"; nativeInstallUrl = "https://herdr.dev/install.sh"; }
  # skills has no install.sh upstream at all - just the npm package of the
  # same name - so it uses nativeInstallNpmPackage instead of nativeInstallUrl.
  { name = "skills"; scope = "basic"; platform = "all"; updatePolicy = "fast"; nativeInstallNpmPackage = "skills"; }
  { name = "pi-coding-agent"; scope = "basic"; platform = "all"; updatePolicy = "fast"; nativeInstallUrl = "https://pi.dev/install.sh"; nativeInstallBinName = "pi"; }
  # gnhf's homebrew-core formula depends on node like the others above (via
  # Homebrew's own dependency resolution); its own npm package of the same
  # name (bin: gnhf) covers Ubuntu the same way skills does.
  { name = "gnhf"; scope = "basic"; platform = "all"; updatePolicy = "fast"; nativeInstallNpmPackage = "gnhf"; }
  # opencode's homebrew-core formula depends on node and ripgrep, resolved by
  # Homebrew itself on macOS; its own install.sh installs to a fixed
  # $HOME/.opencode/bin with no PATH-override env var, so it doesn't fit this
  # loop's ~/.local/bin convention. Its npm package (opencode-ai, bin:
  # opencode) covers Ubuntu the same way skills/gnhf do instead.
  { name = "opencode"; scope = "basic"; platform = "all"; updatePolicy = "fast"; nativeInstallNpmPackage = "opencode-ai"; }
  # no-mistakes has neither a Homebrew formula (`brew info no-mistakes` ->
  # "No available formula", and the kunchenguid/homebrew-no-mistakes tap
  # doesn't exist) nor an npm package - its only fresh-machine install path
  # is its own install.sh. hasHomebrew = false tells tool-selection.nix's
  # useHomebrew/useNative to route it through the native installer on macOS
  # too, not just Ubuntu - the first platform=all/fast tool that needs that
  # (see home.nix's installNativeTools, which now runs on both platforms).
  { name = "no-mistakes"; scope = "basic"; platform = "all"; updatePolicy = "fast"; nativeInstallUrl = "https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.sh"; hasHomebrew = false; }
  # treehouse (git worktree pool manager) does have a real homebrew-core
  # formula (`brew info treehouse` -> homebrew/core, "Manage worktrees
  # without managing worktrees", homepage github.com/kunchenguid/treehouse),
  # so it keeps the default hasHomebrew = true and stays Homebrew-managed on
  # macOS like the rest of this group. Ubuntu uses its own install.sh, which
  # drops a single static Go binary into ~/.local/bin whenever that directory
  # is already on $PATH (installNativeTools exports it before running the
  # script) and never edits a shell rc file. Not nativeInstallNpmPackage: the
  # npm package named "treehouse" is an unrelated React state library, not
  # this tool. Not a plain nixName entry either - nixpkgs has no treehouse
  # attribute (verified with builtins.hasAttr against this flake's nixpkgs).
  { name = "treehouse"; scope = "basic"; platform = "all"; updatePolicy = "fast"; nativeInstallUrl = "https://kunchenguid.github.io/treehouse/install.sh"; }

  # Stable CLI dev tooling wanted on every machine, personal or not.
  { name = "btop"; scope = "basic"; platform = "all"; updatePolicy = "stable"; }
  { name = "mosh"; scope = "basic"; platform = "all"; updatePolicy = "stable"; }
  { name = "bzip2"; scope = "basic"; platform = "all"; updatePolicy = "stable"; }
  { name = "gh"; scope = "basic"; platform = "all"; updatePolicy = "stable"; }
  { name = "gnu-tar"; scope = "basic"; platform = "all"; updatePolicy = "stable"; nixName = "gnutar"; }
  { name = "tree"; scope = "basic"; platform = "all"; updatePolicy = "stable"; }
  { name = "wget"; scope = "basic"; platform = "all"; updatePolicy = "stable"; }
  { name = "cmake"; scope = "basic"; platform = "all"; updatePolicy = "stable"; }
  # Python project runner. platform = "all" + updatePolicy = "stable" means
  # useNix picks it on both targets: home.packages on Ubuntu,
  # environment.systemPackages on macOS (never Homebrew - useHomebrew only
  # claims macOS-specific or fast-moving tools).
  { name = "uv"; scope = "basic"; platform = "all"; updatePolicy = "stable"; }
  { name = "go"; scope = "basic"; platform = "all"; updatePolicy = "stable"; }

  # Stable CLI tooling only personal machines need, but not OS-specific.
  { name = "ffmpeg"; scope = "personal"; platform = "all"; updatePolicy = "stable"; }
  { name = "lcov"; scope = "personal"; platform = "all"; updatePolicy = "stable"; }
  # nixpkgs ships this under the "libusb1" attribute.
  { name = "libusb"; scope = "personal"; platform = "all"; updatePolicy = "stable"; nixName = "libusb1"; }

  # Ubuntu-only build toolchain: nvim-treesitter (main) shells out to `cc`,
  # `make`, and `pkg-config` to compile parsers from source. macOS already
  # has these via Xcode Command Line Tools, so this stays Linux-only.
  { name = "gcc"; scope = "basic"; platform = "ubuntu"; updatePolicy = "stable"; }
  { name = "gnumake"; scope = "basic"; platform = "ubuntu"; updatePolicy = "stable"; }
  { name = "pkg-config"; scope = "basic"; platform = "ubuntu"; updatePolicy = "stable"; }

  # macOS-specific CLI toolchains for this personal Mac (no meaningful
  # Ubuntu equivalent through this same package name/manager).
  { name = "thefuck"; scope = "personal"; platform = "macos"; updatePolicy = "stable"; }
  { name = "echidna"; scope = "personal"; platform = "macos"; updatePolicy = "stable"; }
  { name = "solc-select"; scope = "personal"; platform = "macos"; updatePolicy = "stable"; }
  { name = "tenderly"; scope = "personal"; platform = "macos"; updatePolicy = "fast"; brewName = "tenderly/tenderly/tenderly"; }
  { name = "postgresql"; scope = "personal"; platform = "macos"; updatePolicy = "stable"; brewName = "postgresql@15"; }
  { name = "libpq"; scope = "personal"; platform = "macos"; updatePolicy = "stable"; }
  { name = "colima"; scope = "personal"; platform = "macos"; updatePolicy = "stable"; }

  # macOS GUI apps for this personal Mac only, installed as Homebrew casks.
  { name = "wezterm"; scope = "personal"; platform = "macos"; updatePolicy = "stable"; isCask = true; }
  { name = "opensuperwhisper"; scope = "personal"; platform = "macos"; updatePolicy = "stable"; isCask = true; }
  { name = "slack"; scope = "personal"; platform = "macos"; updatePolicy = "stable"; isCask = true; }
  { name = "discord"; scope = "personal"; platform = "macos"; updatePolicy = "stable"; isCask = true; }
  { name = "notion"; scope = "personal"; platform = "macos"; updatePolicy = "stable"; isCask = true; }
  { name = "figma"; scope = "personal"; platform = "macos"; updatePolicy = "stable"; isCask = true; }
  { name = "altair-graphql-client"; scope = "personal"; platform = "macos"; updatePolicy = "stable"; isCask = true; }
  { name = "mongodb-compass"; scope = "personal"; platform = "macos"; updatePolicy = "stable"; isCask = true; }
  { name = "todoist-app"; scope = "personal"; platform = "macos"; updatePolicy = "stable"; isCask = true; }
  { name = "anki"; scope = "personal"; platform = "macos"; updatePolicy = "stable"; isCask = true; }
  { name = "zoom"; scope = "personal"; platform = "macos"; updatePolicy = "stable"; isCask = true; }
]
