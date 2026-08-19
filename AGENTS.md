# Project notes for agents

Deliberate decisions in this repo - do NOT silently revert them:

- `homebrew.onActivation.cleanup = "zap"` in `configuration.nix` is intentional. It forces the good habit of declaring every Homebrew package in the Nix config instead of installing things ad-hoc, which keeps the machine reproducible. Do not soften it to `uninstall` or `none`. Users are warned about its effect in README.md; this note is for anyone tempted to change the setting itself.
- Never commit `.no-mistakes/` validation evidence to this public repo. `.no-mistakes/` is gitignored; if a validation pipeline stages evidence into a branch, drop it before merging.
- `configuration.nix` splits both Homebrew `brews` and `casks` into `basicBrews`/`basicCasks` (dev tooling) and `personalBrews`/`personalCasks` (this Mac's GUI apps and personal tools), combined via one shared `usePersonalSetup` module argument (required, no default - nix-darwin doesn't honor plain Nix argument defaults for custom module args, so `flake.nix`'s `specialArgs` must always supply it). One toggle deliberately gates both lists - don't add a separate toggle per list.
- Linux (Ubuntu 22.04, not NixOS) is managed by a separate `homeConfigurations."<user>@<system>"` output in `flake.nix` (standalone home-manager, no nix-darwin/nix-homebrew/Homebrew - those are macOS-only concepts with no Linux port). `home.nix` is shared between platforms; it branches only on `pkgs.stdenv.isDarwin`/`isLinux` for the home directory and for the handful of `basicBrews`/`basicCasks` entries that have a nixpkgs equivalent worth installing on Linux. `bootstrap.sh`/`rebuild.sh` branch on `uname -s`/`uname -m` the same way. When adding a new `basicBrews`/`basicCasks` entry, check whether it has a nixpkgs equivalent under *this repo's pinned* `nixpkgs` revision specifically (`nix eval .#legacyPackages.x86_64-linux.<pkg>.meta.available`) - the public `nixpkgs` flake registry can be newer and show a package (e.g. `herdr`) that isn't in the pin yet.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
