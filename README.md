# dotfiles

Watch the walkthrough: https://youtu.be/5N-okeDdIuI

My personal Mac setup, managed with nix-darwin and home-manager.
One repo, one command, and a fresh Mac ends up configured the same way every time.
Bare Ubuntu 22.04 LTS is supported too, through standalone home-manager.

## Contributing / Using This Repo

These are my personal dotfiles, shared publicly so people can read them, learn from them, and fork them freely.
Feature requests and pull requests are not accepted here, and PRs are auto-closed.
If you find a bug, please open a GitHub Issue using the bug report template.

## What you get

On macOS:

- System settings (dark mode, key repeat, dock, Finder, trackpad)
- Homebrew apps (casks and CLI tools)
- Nix user packages (ripgrep, fd, fzf, jq, lazygit, Neovim, Hack Nerd Font, TeX Live)
- Shell (zsh, aliases, starship prompt)
- Neovim and WezTerm, both on the rose-pine moon theme
- Agent configs (Claude, Codex, opencode all share one AGENTS.md)
- Optional Pi theme, local extensions, settings/model overrides, and two pinned third-party packages

Ubuntu gets the shared shell, CLI packages, prompt, git, and symlinked dotfiles. See "Ubuntu setup".

## Prerequisites

- Apple Silicon Mac by default. On Intel, set `nixpkgs.hostPlatform = "x86_64-darwin";` in `configuration.nix`.
- Ubuntu 22.04 LTS (a plain install, no desktop environment) also works. See "Ubuntu setup" instead of the macOS steps below.

## Fresh-machine setup

Read "Make it yours" first. `bootstrap.sh` applies the config to your machine, and Homebrew cleanup can uninstall packages you already have.

```sh
git clone https://github.com/kunchenguid/dotfiles.git
cd dotfiles
cp .env.example .env
# set DOTFILES_SETUP=personal (full setup) or DOTFILES_SETUP=basic (dev tooling only)
./bootstrap.sh
```

`bootstrap.sh` reads `DOTFILES_SETUP` and refuses to go further without it, installs Determinate Nix, symlinks the repo to `~/.dotfiles` (the build resolves config files through that path), offers to fix `flake.nix`'s `user` line if it does not match your macOS username, marks the repo safe for root (`darwin-rebuild` runs under `sudo`, so root evaluates this flake's `git+file://` input), then runs the first `darwin-rebuild switch`.

After that you are on the normal workflow below.

### Validate without applying

```sh
nix flake check --no-build
nix build .#darwinConfigurations.mac.system --dry-run
./test.sh
```

Substitute your own host label for `mac` if you renamed it. On Ubuntu, build `.#homeConfigurations."<user>@<system>".activationPackage` instead (e.g. `thomasharper@x86_64-linux`).

## Daily use

Edit the config files in place, then apply:

```sh
./rebuild.sh
```

That's it. No separate build-and-copy step.

## Ubuntu setup

Standalone home-manager, not nix-darwin: user-level only. No sudo rebuild, no Homebrew, no system config. Just your shell, git, starship, zoxide, and the symlinked dotfiles under `home/`.

```sh
git clone https://github.com/kunchenguid/dotfiles.git
cd dotfiles
cp .env.example .env   # `basic` is the usual choice on a server
./bootstrap.sh
```

Same shape as the macOS bootstrap, ending in `home-manager switch --flake ~/.dotfiles#<user>@<system>` instead of `darwin-rebuild switch`. `<system>` is `x86_64-linux` or `aarch64-linux`, detected from `uname -m`, and `basic` adds a `-basic` suffix to the output name.

Two extra steps need `sudo`. Both are fault-isolated: if `sudo` is unavailable they warn and print the manual commands rather than failing a bootstrap that otherwise succeeded.

- **Login shell.** This repo configures `programs.zsh` and nothing else, so on a box still logging you into `/bin/bash` none of it is ever sourced: no aliases, and no `SSH_AUTH_SOCK`, which shows up as every `git pull` re-prompting for your key passphrase. The step adds the Nix zsh to `/etc/shells` and refuses to switch if that zsh does not start, since `sshd` hands you your login shell and nothing else. Open a new SSH session to pick it up. macOS already logs into zsh.
- **`uidmap`.** For rootless Docker, below.

### Rootless Docker

`home.nix` runs Docker as a rootless `systemd --user` service (`systemctl --user status docker`) with `DOCKER_HOST` set to `unix:///run/user/$(id -u)/docker.sock`. `pkgs.docker` ships `dockerd-rootless` and everything it shells out to, except one file: setuid `/usr/bin/newuidmap`, which a Nix store binary can never be. Hence the `uidmap` apt package; without it the unit dies with `newuidmap: executable file not found in $PATH`. The daemon survives between SSH sessions via `enable-linger`, same as the ssh-agent. macOS uses Colima instead.

### What Ubuntu does not get

No Homebrew casks or GUI apps (no desktop environment to run them), and no `platform = "macos"` tools from `tools.nix`: `thefuck`, `echidna`, `solc-select`, `foundry`, `tenderly`, `postgresql`, `libpq`, `colima`.

Fast-moving `platform = "all"` tools have no Nix path here, so `home.nix`'s `installNativeTools` activation script installs each from its own `nativeInstallUrl` script or `nativeInstallNpmPackage`, skipping any already present in `~/.local/bin` (see `nativeInstallBinName` for tools whose launcher name differs from their entry name). It pre-creates and exports `~/.local/bin` and sets `CODEX_NON_INTERACTIVE=1` and `NPM_CONFIG_PREFIX=$HOME/.local`, so no installer prompts or rewrites a shell rc, and `home.sessionPath` keeps that directory reachable afterwards.

`NPM_CONFIG_PREFIX` is *also* set via `home.sessionVariables` (Linux only), so interactive shells resolve `npm root -g` to `~/.local/lib/node_modules` rather than the read-only Nix store. Both must stay in sync: the generated activation script runs with its own environment and never sources `hm-session-vars.sh`. `pkgs.nodejs` is in `home.packages` on Linux because the npm-backed launchers shebang into `node` at runtime, not just during install. macOS is unaffected, and the attribute is gated with `lib.optionalAttrs` so it is absent from the darwin evaluation entirely.

## Make it yours

This repo is mine. Review these before you run `bootstrap.sh`:

- **Username**: run `./bootstrap.sh` (it detects yours and offers to set it), or change the single `user = "kunchen"` line in `flake.nix`. Everything else threads from that variable.
- **Host label**: change the single `hostLabel = "mac";` line in `flake.nix`.
- **CPU architecture**: on macOS set `hostPlatform` in `configuration.nix`; on Ubuntu the scripts map `uname -m` for you.

### Setup profile

Every machine picks one profile, and `bootstrap.sh` and `rebuild.sh` both refuse to run until it has. Set `DOTFILES_SETUP` in `.env` to one of:

- `personal` - the full setup: `scope = "personal"` formulae and GUI casks on macOS (Slack, Discord, Notion, Figma, ...) on top of the shared dev tooling, plus the full TeX Live scheme.
- `basic` - dev tooling only, the sensible choice on a server: no personal formulae or casks, minimal TeX Live (`pdflatex`/`xelatex`).

`.env` is gitignored, because "is this a personal machine" is a per-machine answer; a committed file would drag the choice onto every other machine on the next `git pull`.

It is a flake output per profile rather than a value `flake.nix` reads, because Nix evaluates this repo as a git tree and an untracked file never reaches the store. So `flake.nix` builds both (`mac` and `mac-basic`, `<user>@<system>` and `<user>@<system>-basic`), and `setup-env.sh` turns `DOTFILES_SETUP` into the suffix or refuses. `tests/setup-env.test.sh` covers the refusals and that every suffix names a real output.

To switch profiles, edit `.env` and run `./rebuild.sh`. Going `personal` -> `basic` on macOS removes the personal casks, because `homebrew.onActivation.cleanup = "zap"` uninstalls anything the config no longer declares.

### Local and private files

**Private shell values:** copy `home/.config/zsh/private-env.zsh.example` to `home/.config/zsh/private-env.zsh` and fill in local-only values. The real file is gitignored. Setting `HETZNER_HOST` there, for example, enables the `hetzner` zsh alias without committing the host.

**SSH config:** `~/.ssh/config` is never managed by home-manager. It stays local so Colima and other tools can rewrite it freely. Instead, `home.nix` symlinks two fragments into `~/.ssh/` and idempotently prepends `Include` lines for them on every rebuild, never duplicating them and never touching the rest of the file:

- `~/.ssh/dotfiles.config.public` - general defaults, from the committed per-platform `home/.ssh/dotfiles.config.public.darwin` or `.linux`.
- `~/.ssh/dotfiles.config.private` - your real per-host entries. Copy `home/.ssh/dotfiles.config.private.example` to `home/.ssh/dotfiles.config.private`; the real file is gitignored.

On a new machine the first switch creates `~/.ssh/config` and wires both `Include` lines automatically. If you used the older `home/.ssh/config.private`, copy its entries across by hand; it is not renamed for you.

**Persistent ssh-agent (Linux only):** `home.nix` enables home-manager's `services.ssh-agent`, a `systemd --user` unit that starts on login with `SSH_AUTH_SOCK` wired into zsh. Note *zsh*: that module only injects the socket into shells home-manager manages, which is why `bootstrap.sh` changes your login shell. Systemd lingering keeps the agent and its cached keys alive after the SSH session closes, so with `AddKeysToAgent yes` a passphrase is entered once per boot. macOS gets this for free via launchd and the Keychain.

**Git identity:** deliberately not set here. Git will stop your first commit and tell you to set `user.name` and `user.email`. To manage it declaratively, add to `home.nix`:

```nix
programs.git = {
  enable = true;
  settings.user = {
    name = "Your Name";
    email = "you@example.com";
  };
};
```

### Warnings

**Homebrew cleanup:** `configuration.nix` sets `homebrew.onActivation.cleanup = "zap"`. Every macOS switch removes any package or cask not selected from `tools.nix`. If you already have Homebrew packages installed, the first switch uninstalls them. Read the Homebrew-selected entries in `tools.nix` and add anything you want to keep before your first run.

**Existing Homebrew install:** `nix-homebrew.autoMigrate = true`, so an existing non-Nix `/opt/homebrew` is migrated in place rather than erroring out. Taps and packages are kept; the `zap` cleanup above still applies on top.

**Existing dotfiles:** `home-manager.backupFileExtension = "before-home-manager"`, so files like `~/.zshrc` or `~/.claude/settings.json` are moved to `<name>.before-home-manager` instead of blocking activation. Diff them afterwards if you want to carry anything over.

**Agent policy:** `home/AGENTS.md` is my personal agent policy, installed for Claude, Codex, and opencode. Clone this repo and you silently inherit it. Edit or delete it if you don't want that.

**High-agency aliases:** `cc`, `co`, and `ag` in `home.nix` are `claude --dangerously-skip-permissions`, `codex -s workspace-write -a never`, and `cursor-agent --force --trust --approve-mcps --sandbox disabled`. Know what they do before you use them.

### Package metadata

`tools.nix` is the single source of truth for every CLI tool and GUI app. Each entry answers:

| Property       | Question                                          | Values                     |
| -------------- | ------------------------------------------------- | -------------------------- |
| `scope`        | Do I need this on a minimal dev machine?          | `basic` / `personal`       |
| `platform`     | Where does this tool make sense?                  | `all` / `macos` / `ubuntu` |
| `updatePolicy` | Do I want the latest upstream version quickly?    | `stable` / `fast`          |
| `isCask`       | If installed through Homebrew, is it a cask?      | `true` / omitted           |
| `hasHomebrew`  | Does this tool have a real Homebrew formula/cask? | `true` (default) / `false` |

Optional overrides, used only where a tool needs them:

| Field                     | Purpose                                                    |
| ------------------------- | ---------------------------------------------------------- |
| `brewName` / `nixName`    | Package name differs from the entry `name`                 |
| `nativeInstallUrl`        | Non-interactive installer script for a `useNative` tool    |
| `nativeInstallNpmPackage` | Same idea, for a tool distributed only as an npm package   |
| `nativeInstallBinName`    | Launcher name the "already installed" skip-check looks for |

Why a given tool is wired the way it is - no Homebrew formula, a hardcoded install path, a colliding npm name - is commented on its own `tools.nix` entry. If you don't use one, delete its entry; for `herdr`, also delete the `installHerdrAgentIntegrations` block in `home.nix`.

`tool-selection.nix` turns that table into concrete selections in two stages, shared by `configuration.nix` (macOS) and `home.nix` (both platforms). First, whether the tool exists on this machine at all:

```text
scope:
  basic setup    -> only scope=basic
  personal setup -> basic + personal

platform:
  platform=all             -> any OS
  platform=currentPlatform -> this OS
  anything else            -> skip
```

Only then is the installer picked, based on `currentPlatform`:

```text
macOS:
  stable + all              -> Nix
  fast + all + hasHomebrew  -> Homebrew
  fast + all + !hasHomebrew -> native installer
  macos-only                -> Homebrew

Ubuntu:
  stable + all     -> Nix
  fast + all       -> native installer
  stable + ubuntu  -> Nix
  fast + ubuntu    -> native installer
```

A native installer only actually runs for tools that set `nativeInstallUrl` or `nativeInstallNpmPackage`.

The invariant that keeps the two paths aligned: installer selection depends on `currentPlatform`, never on a tool's fields alone. The same `platform=all; updatePolicy=fast` tool is Homebrew-managed on macOS and natively installed on Ubuntu. `hasHomebrew = false` is the one exception, routing a tool with no formula through the native installer on macOS too. `isCask` only picks `homebrew.casks` over `homebrew.brews` for a tool already selected for Homebrew.

`currentPlatform` is not a global constant: `configuration.nix` hardcodes `"macos"`, while each Ubuntu `homeConfigurations."<user>@<system>"` output derives it from `pkgs.stdenv.isDarwin`. The scope toggle, `usePersonalSetup`, comes from `.env` rather than a repo edit that would follow you onto every machine.

## Repo tour

- `flake.nix` - the entry point. Wires nixpkgs, nix-darwin, home-manager, and nix-homebrew for `darwinConfigurations.mac`, and nixpkgs + standalone home-manager for the Linux `homeConfigurations."<user>@<system>"` outputs. Every output is built twice, once per setup profile.
- `.env.example` / `setup-env.sh` - the per-machine setup profile and the suffix it maps to.
- `configuration.nix` - macOS system-level config: system defaults, Homebrew, macOS package selection.
- `tools.nix` - the per-tool metadata table.
- `tool-selection.nix` - the shared predicates that turn `tools.nix` into concrete installers for one `currentPlatform`.
- `home.nix` - user-level config for both platforms: shell, packages, prompt, symlinks. Platform-specific bits branch on `pkgs.stdenv.isDarwin`.
- `rebuild.sh` - re-applies the config after the first switch.
- `home/` - the actual config files that get symlinked into place.
- `agent-capabilities.toml` / `agent-capabilities.sh` - declares and syncs agent skills, plugins, and Pi extras.

## How the symlinks work

The files under `home/` are the real files: editing them here is editing your live config, no rebuild needed.
`home.nix` uses `mkOutOfStoreSymlink` to point paths like `~/.config/nvim` straight at this repo, so the two never drift.
Run `./rebuild.sh` only when you change something that isn't a symlinked file, like a package list or a system default.

## Optional Pi configuration

Pi is an opt-in CLI, not a dependency this repository vendors. The CLI is selected through `tools.nix` like everything else; install it from its owner with the [official Pi instructions](https://pi.dev) if you adapt only this config. [Pi Launcher](https://github.com/kunchenguid/homebrew-tap) is also optional and installed separately:

```sh
brew install --cask kunchenguid/tap/pi-launcher
```

Home Manager owns exactly two Pi directories, `~/.pi/agent/themes` and `~/.pi/agent/extensions`, plus `models.json` and `settings.json` as individual files. The extensions directory is for public, repository-authored extensions only; third-party package code never belongs there. Run `/reload` after editing one. The `rose-pine-moon` theme was authored clean-room from the public [Rosé Pine Moon palette](https://rosepinetheme.com/palette) and Pi's public theme schema.

Home Manager deliberately does not manage `~/.pi/agent` itself, or Pi authentication, sessions, trust decisions, caches, or package trees. The model overrides carry no credentials, choose no default model, and only take effect once you authenticate Pi yourself.

### Pi Calm

`home/.pi/agent/extensions/calm` is a standalone local extension, auto-loaded through the existing extensions-directory link. `/calm` toggles a conversation-only presentation mode, off by default, stored in `~/.pi/agent/calm` rather than in this repository. Adapted from Firstmate under the bundled MIT license, with no imports of or runtime dependency on it.

When enabled, Calm hides collapsed thinking and the call/result shells for Pi's seven built-in tools without leaving blank transcript rows, and replaces the working row with a two-line animated widget. `/calm` restores stock rendering and preserves your Ctrl+O tool-expansion choice.

Calm never changes prompts, tool execution, model context, session data, or ordering; `/share` and `/export` use the complete stock transcript. Custom tools, images, and unsupported transcript classes stay visible, because Pi has no safe general-purpose transcript filter. If a future Pi release drops the rendering seam it hooks, Calm logs one diagnostic and disables only that adapter.

### Pinned third-party Pi packages

`settings.json` declares two, both as immutable pins so Pi never moves them during package updates:

- `npm:@ryan_nookpi/pi-extension-codex-fast-mode@0.2.6`
- `git:github.com/algal/pi-openai-server-compaction@c6d593087709e9481223dc6c6c2269b371b5e055`

**Both execute with your full user permissions and must be trusted like any other executable code.** The compaction package is experimental, sends the relevant OpenAI compaction and continuity data to OpenAI, and upstream declares the stale peer range `>=0.80.9 <0.81.0`; this exact ref was locally proven to load and perform remote compaction on Pi 0.82.0, which is not a guarantee for any other Pi version or package ref. Updating either one requires a new source, a security audit, and an explicit pin change in `home/.pi/agent/settings.json`.

On Pi 0.82.0 these install automatically at startup; no one-time command is needed. Pi keeps the downloaded trees in its own unmanaged `~/.pi/agent/npm` and `~/.pi/agent/git` directories.

## Agent capabilities (skills, plugins, Pi extras)

`agent-capabilities.toml` is the repo-tracked source of truth for the skills, Claude Code plugins, and repo-authored Pi extras this setup expects across Codex, Claude Code, Pi, and opencode. It declares desired state only: no hand-rolled package manager, and it never touches runtime, cache, or plugin internals. It drives each ecosystem's own mechanism:

- **Skills** (`kind = "skill"`) install through the [`skills` CLI](https://skills.sh). `source = "owner/repo"` is a package spec; `source = "local"` marks a skill with no reproducible remote source, declared for visibility but always reported as `manual-action-required`.
- **Claude Code plugins** (`kind = "plugin"`) install through `claude plugin marketplace add` then `claude plugin install <name>@<marketplace>`. Codex has equivalent commands but nothing seeded.
- **Pi extras** (`kind = "pi-extension"` / `"pi-theme"`) are listed for visibility only; Home Manager owns them, so sync no-ops and points at `./rebuild.sh`.
- **opencode** discovers skills from `~/.claude/skills` and `~/.agents/skills` and has no plugin marketplace, so an opencode target is satisfied once the Codex or Claude Code copy is in place.

Manifest fields: `name`, `kind`, `source`, optional `path` (defaults to `"."`, only for Pi extras), `targets` (subset of `codex`/`claude`/`opencode`/`pi`), and `id` (plugin only).

```sh
./agent-capabilities.sh check              # honest drift report (read-only)
./agent-capabilities.sh check --json       # machine-readable
./agent-capabilities.sh sync               # idempotent install, refuses local edits without --force
./agent-capabilities.sh sync --dry-run     # show what sync would do, run nothing
./agent-capabilities.sh sync --force       # overwrite local edits / adopt pre-existing directories
```

`check` reports, per target and kind: installed, declared-but-missing, installed-but-undeclared, stale lock entries, and manual-action-required. `sync` is safe to rerun: a directory that already exists but was never synced by this tool, or whose content changed since, is reported rather than overwritten unless you pass `--force`.

To add a skill or plugin, add a `[[capability]]` entry and run `./agent-capabilities.sh sync`. On a new machine, run it after `./rebuild.sh`.

## Notes

The first `nvim` launch bootstraps [lazy.nvim](https://github.com/folke/lazy.nvim) by cloning plugins from GitHub. That needs network once; after that it is offline. Neovim keeps italics off and uses a transparent background so it matches the terminal.

Python gets `basedpyright` and `ruff`, installed by `mason` on first non-headless launch, so `:Mason` is where you watch or retry. Nix gets `nixd`, installed by `tools.nix` instead: mason's registry has no `nixd`, and its only other Nix server (`nil`) is a cargo package needing a Rust toolchain everywhere. So `nixd` needs a `./rebuild.sh`, not a `:Mason` run. Ubuntu also gets Nix's `python3`, because mason installs basedpyright into a venv and Ubuntu's system interpreter ships without `ensurepip`; macOS already has a working one from the Xcode Command Line Tools, and a Nix `python3` would shadow it. All configured in `home/.config/nvim/lua/plugins/lsp.lua`.

[conform.nvim](https://github.com/stevearc/conform.nvim) formats on demand, never on save: `<leader>F` formats the buffer with `ruff_format` for python and `prettier` for markdown, yaml, json, html, and css. Formatting rewrites the whole buffer, so on-save would turn a one-line fix in a never-formatted project into hundreds of lines of churn, and `<Esc>` is mapped to `:w` so it would fire constantly. Each formatter reads the edited project's own config; no house style is imposed from here. lua and nix are deliberately unmapped, since `stylua` and `nixfmt` disagree with this repo's hand-formatting wholesale.

## License

This repo is licensed under MIT No Attribution.
See `LICENSE`.
