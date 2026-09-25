# Cheat sheet

Every command, alias, and keybinding this dotfiles repo gives you, in one glance-reference. Everything below is defined in a real file in this repo (`home.nix`, `tools.nix`, `home/.config/**`, or the root scripts); nothing here is generic advice.

## Rebuild and maintenance

| Command | What it does | Platform |
| --- | --- | --- |
| `./bootstrap.sh` | Fresh machine setup, then leaves you on `./rebuild.sh` | Both |
| `./rebuild.sh` | Apply config changes (the daily command) | Both |
| `./test.sh` | Run every `tests/*.test.sh`, print pass/fail summary | Both |
| `nix flake check --no-build` | Validate the flake without applying | Both |
| `nix build --impure .#darwinConfigurations.mac.system --dry-run` | Dry-run the macOS build (`mac` = `hostLabel` in `flake.nix`) | macOS |
| `nix build --impure .#homeConfigurations."<user>@<system>".activationPackage --dry-run` | Dry-run the Linux build, e.g. `"$(id -un)@x86_64-linux"` | Linux |
| `sudo env DOTFILES_USER=$(id -un) darwin-rebuild switch --impure --flake ~/.dotfiles#mac` | What `rebuild.sh` execs on macOS | macOS |
| `home-manager switch --impure --flake ~/.dotfiles#<user>@<system>` | What `rebuild.sh` execs on Linux, no sudo | Linux |
| `systemctl --user status docker` | Check the rootless Docker daemon `home.nix` runs | Linux |
| `herdr integration install claude\|codex\|pi` | Agent hooks; `rebuild.sh` already runs this every time | Both |

Manual `nix`/`darwin-rebuild`/`home-manager` invocations need `--impure` and `DOTFILES_USER` in the environment: the username comes from `.env`, not from a tracked file. `./rebuild.sh` and `./bootstrap.sh` do this for you.

## Shell aliases

Defined in `home.nix` `programs.zsh.shellAliases`.

| Alias | Expands to | Platform |
| --- | --- | --- |
| `..` | `cd ..` | Both |
| `cpath` | ``echo -n `pwd` \| pbcopy`` - copy cwd to clipboard | macOS only |
| `disablesleep` | `sudo pmset -a disablesleep 1` | macOS only |
| `enablesleep` | `sudo pmset -a disablesleep 0` | macOS only |

### AI agent aliases

| Alias | Expands to | Notes |
| --- | --- | --- |
| `cc` | `claude --dangerously-skip-permissions` | High agency, no prompts |
| `co` | `codex -s workspace-write -a never` | Writes in workspace, never asks |
| `ag` | `cursor-agent --force --trust --approve-mcps --sandbox disabled` | High agency, no prompts, no sandbox |
| `askclaude` | `claude -p --tools=""` | One-shot, no tools |
| `askpi` | `pi --no-context-files --exclude-tools read,write,edit,bash -p` | One-shot, no tools |
| `askcodex` | `codex exec --ephemeral --sandbox read-only` (function) | One-shot, no tools; answer only, stderr shown only on failure |
| `askcursor` | `cursor-agent -p --mode ask --trust` | One-shot, no tools |
| `doclaude` | `claude -p` | One-shot, full tools |
| `dopi` | `pi -p` | One-shot, full tools |
| `docodex` | `codex exec` | One-shot, full tools |
| `chatclaude` | `claude --tools ""` | Interactive, no tools |
| `chatpi` | `pi --no-context-files --exclude-tools read,write,edit,bash` | Interactive, no tools |
| `chatcodex` | `codex --sandbox read-only --ask-for-approval never` | Interactive, no tools |
| `chatcursor` | `cursor-agent --mode ask` | Interactive, no tools |

### Zsh keybindings

| Key | What it does |
| --- | --- |
| `Ctrl-F` | Accept the ghost-text autosuggestion |
| `Ctrl-G` | `ai-fill-buffer`: rewrite the current line as an AI-generated command, no execution |

Autosuggestions (history ghost text) and syntax highlighting (valid commands turn green) are always on.

## Git

| Command | What it does |
| --- | --- |
| `add` | `git add .` |
| `push` | `git push` |
| `pull` | `git pull` |
| `m` | `git switch main` |
| `gitverify` | `ssh-add ~/.ssh/id_rsa` - unlock the key into the agent |
| `lazygit` | Full-screen git TUI |
| `gh` | GitHub CLI (PRs, issues, releases) |
| `treehouse` | Git worktree / Jujutsu workspace pool manager |

No `programs.git.aliases` are defined; `home.nix` sets only user name and email.

## Navigation and search

| Command | What it does | Notes |
| --- | --- | --- |
| `cd <partial>` | zoxide jump to a frecent directory | zoxide replaces `cd` via `--cmd cd` |
| `cdi` | zoxide interactive directory picker | zoxide's `--cmd cd` companion |
| `rg <pattern>` | ripgrep - fast recursive search | |
| `fd <name>` | fast file find | |
| `fzf` | Fuzzy finder | Installed as a plain binary, no shell-widget integration configured |
| `tree` | Directory tree | |
| `jq` | JSON on the command line | |

## CLI tools

Everything selected by `tools.nix` / `tool-selection.nix`, plus `home.packages` in `home.nix`.

### Everywhere (macOS and Linux)

| Command | What it does |
| --- | --- |
| `nvim` | Neovim (also `$EDITOR`) |
| `rg` / `fd` / `fzf` / `jq` | Search, find, fuzzy-pick, JSON |
| `lazygit` | Git TUI |
| `docker` / `docker compose` | Containers; rootless systemd user daemon on Linux, Colima on macOS |
| `tree-sitter` | Treesitter CLI, needed by nvim-treesitter |
| `btop` | Process / resource monitor |
| `mosh` | Roaming SSH replacement |
| `gh` | GitHub CLI |
| `tree` | Directory tree |
| `wget` | HTTP download |
| `cmake` | Build system generator |
| `uv` | Python project runner |
| `tar` / `gzip` / `bzip2` | Archives |
| `pdflatex` / `xelatex` | TeX Live; full scheme when `.env` has `DOTFILES_SETUP=personal`, otherwise basic |
| `claude` | Claude Code |
| `codex` | OpenAI Codex CLI |
| `pi` | Pi coding agent |
| `opencode` | opencode agent |
| `herdr` | Terminal multiplexer / agent herder |
| `skills` | Skills CLI |
| `gnhf` | gnhf CLI |
| `no-mistakes` | Validation pipeline CLI |
| `treehouse` | Worktree pool manager |
| `specify` | GitHub Spec Kit CLI (`specify init` scaffolds spec-driven projects) |

### Blockchain dev only (`BLOCKCHAIN_DEV=true` in `.env`)

| Command | What it does | Platform |
| --- | --- | --- |
| `forge` (foundry) | Build, test and deploy Solidity projects | Both |
| `cast` (foundry) | Chain RPC calls, ABI/unit conversion, tx inspection | Both |
| `anvil` (foundry) | Local Ethereum dev node | Both |
| `chisel` (foundry) | Solidity REPL | Both |
| `echidna` | Solidity fuzzer | macOS only |
| `solc-select` | Switch solc versions | macOS only |
| `tenderly` | Tenderly CLI | macOS only |

### Personal machines only (`DOTFILES_SETUP=personal` in `.env`)

| Command | What it does | Platform |
| --- | --- | --- |
| `ffmpeg` | Media transcoding | Both |
| `lcov` | Coverage reports | Both |
| `libusb` | USB library | Both |
| `fuck` (thefuck) | Correct the previous command | macOS only |
| `echidna` | Solidity fuzzer | macOS only |
| `solc-select` | Switch Solidity compiler versions | macOS only |
| `tenderly` | Tenderly CLI | macOS only |
| `psql` (postgresql@15) | Postgres client/server | macOS only |
| `libpq` | Postgres client library | macOS only |
| `colima` | Docker runtime for macOS | macOS only |

### Linux-only extras

| Command | What it does |
| --- | --- |
| `gcc` / `make` / `pkg-config` | Build toolchain so nvim-treesitter can compile parsers |
| `node` / `npm` | Runtime for the npm-backed agent CLIs; `NPM_CONFIG_PREFIX=$HOME/.local` |

### macOS GUI apps (casks, personal setup only)

WezTerm, OpenSuperWhisper, Slack, Discord, Notion, Figma, Altair GraphQL Client, MongoDB Compass, Todoist, Anki, Zoom, Skim (PDF reader).

## Neovim

Runs [LazyVim](https://www.lazyvim.org/) close to stock, so its docs apply as written. **Leader is `Space`**; which-key pops up as you type it, and `<leader>sk` searches every keymap. Only what is listed as *ours* comes from this repo.

### Files, buffers, search

| Key | What it does |
| --- | --- |
| `<leader><space>` | Find files (root dir) |
| `<leader>/` | Grep (root dir) |
| `<leader>,` | Buffers |
| `<leader>e` | Explorer (snacks) |
| `<leader>o` | **ours** - Oil, edit the parent directory as a buffer |
| `H` / `L` | Previous / next buffer |
| `s` / `S` | Flash jump / Flash treesitter |
| `p` (visual) | **ours** - paste over a selection without clobbering the register |

### LSP

Buffer-local, so they appear once a server attaches.

| Key | What it does |
| --- | --- |
| `gd` / `gr` / `gI` / `gy` | Definition / references / implementation / type definition |
| `K` | Hover docs |
| `<leader>ca` | Code action |
| `<leader>cr` / `<leader>cR` | Rename symbol / rename file |
| `<leader>cd` / `<leader>xx` | Line diagnostics / diagnostics list (Trouble) |
| `<leader>cm` | Open `:Mason` to watch or retry server installs |

### Git

| Key | What it does |
| --- | --- |
| `<leader>gg` | Lazygit (root dir) |
| `]h` / `[h` | Next / previous hunk |
| `<leader>ghb` | Blame line (there is no always-on inline blame) |

### Formatting

Format-on-save is **off** (`vim.g.autoformat = false`, ours). LazyVim defaults it on, and maps `stylua` to lua and `nixfmt` to nix - which would rewrite `home.nix` or any `.lua` file here wholesale on a one-character edit.

| Key | What it does |
| --- | --- |
| `<leader>cf` | Format the buffer now |
| `<leader>uf` / `<leader>uF` | Toggle auto-format globally / for this buffer |

### Other

| Key / setting | Effect |
| --- | --- |
| `<leader>uC` | Colorscheme picker, live preview - `rose-pine-moon` is active, matching WezTerm |
| `<C-Space>` | Treesitter incremental selection. WezTerm's leader eats it, so press `Ctrl-Space` twice |
| `<M-j>` / `<M-k>` | Move the current line down / up |
| `<C-h>` `<C-j>` `<C-k>` `<C-l>` | Move between windows |
| `:LazyExtras` | Add or remove language support; writes `lazyvim.json` |
| `:Lazy` | Plugin manager; `lazy-lock.json` is committed |

## WezTerm

**Leader is `Ctrl-Space`** (1000 ms timeout). macOS's "select previous input source" shortcut is disabled in `configuration.nix` to free it up.

| Key | What it does |
| --- | --- |
| `Leader` `[` | Enter copy mode |
| `Leader` `Ctrl-Space` | Send a literal `Ctrl-Space` through |
| `Leader` `%` | Split pane horizontally |
| `Leader` `"` | Split pane vertically |
| `Leader` `h` / `j` / `k` / `l` | Move focus left / down / up / right |
| `Leader` `x` | Close current pane (with confirm) |
| `Leader` `g` | Send `Ctrl-G` - triggers the zsh AI fill-buffer |
| `Cmd` `h` / `j` / `k` / `l` | Send raw arrow keys, for Vim-style nav in TUI grids |

`Cmd+hjkl` uses Cmd because macOS never delivers it to terminal programs, so it cannot shadow a Neovim mapping - Option did, eating LazyVim's `<M-j>`/`<M-k>`. It costs WezTerm's own `Cmd+h` (hide app) and `Cmd+k` (clear scrollback).

WezTerm is a personal-setup macOS cask.

## herdr

Multiplexer keybindings from `home/.config/herdr/config.toml`. **Prefix is `Ctrl-B`.**

| Key | What it does |
| --- | --- |
| `Prefix` `h` / `j` / `k` / `l` | Focus pane left / down / up / right |
| `Prefix` `"` | Split horizontally |
| `Prefix` `%` | Split vertically |
| `Prefix` `c` | New tab |
| `Prefix` `&` | Close tab |
| `Prefix` `w` | Workspace picker |
| `Prefix` `g` | Goto |
| `Prefix` `[` | Copy mode |
| `j` / `k` (navigate mode) | Move down / up through workspaces |

Copy mode's own keys are fixed upstream: `v` or `Space` select, `y` or `Enter` copy, `q` or `Esc` cancel.

## SSH hosts

| Command | What it does | Notes |
| --- | --- | --- |
| `ssh github.com` | Uses `~/.ssh/id_rsa`, keys added to agent | From `home/.ssh/dotfiles.config.public.{darwin,linux}` |
| `hetzner` | `ssh <user>@$HETZNER_HOST` | Only exists if `HETZNER_HOST` is set in the gitignored `home/.config/zsh/private-env.zsh` (copy the `.example`) |
| `ssh <yourhost>` | Your own per-host entries | Defined in the gitignored `home/.ssh/dotfiles.config.private` (copy the `.example`); the committed repo has none |

`~/.ssh/config` itself is never managed; `home.nix` only prepends `Include` lines for the two fragments above.

## Agent extras

| Command | What it does |
| --- | --- |
| `/calm` (in Pi) | Toggle the conversation-only presentation mode; off by default, choice stored in `~/.pi/agent/calm` |
| `/reload` (in Pi) | Reload after editing a local extension or Pi resource |
| `brew install --cask kunchenguid/tap/pi-launcher` | Optional Pi Launcher, not declared by this config |
