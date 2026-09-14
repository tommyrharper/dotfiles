{
  description = "dotfiles";

  inputs = {
    # Use `github:NixOS/nixpkgs/nixpkgs-26.05-darwin` to use Nixpkgs 26.05.
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    # Use `github:nix-darwin/nix-darwin/nix-darwin-26.05` to use Nixpkgs 26.05.
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs = inputs@{ self, nix-darwin, nix-homebrew, home-manager, nixpkgs }:
    let
      # The one username line to change if this isn't your machine.
      # bootstrap.sh offers to rewrite this for you if your local username differs.
      user = "thomasharper";
      # The one host label to change if you want to rename the machine.
      # rebuild.sh and bootstrap.sh read this back out of flake.nix, so it
      # only needs to be changed here.
      hostLabel = "mac";
      # Every target is built once per setup profile and BLOCKCHAIN_DEV value,
      # and the suffix is what tells them apart in the output name:
      #   usePersonalSetup = true installs personal brews and GUI casks on macOS
      #   (Slack, Discord, Notion, Figma) alongside the shared dev tooling, and
      #   selects the full TeX Live scheme (all packages/engines) on every OS;
      #   false installs dev tooling only (e.g. for a server), with the minimal
      #   TeX Live scheme (just pdflatex/xelatex).
      #
      # Which one a given machine gets is not decided here: it is a per-machine
      # choice living in the gitignored root .env (see .env.example), and
      # flake.nix cannot read that file at all - Nix evaluates this repo as a
      # git tree, so untracked files never reach the store. setup-env.sh turns
      # DOTFILES_SETUP and BLOCKCHAIN_DEV into the suffix below, and
      # bootstrap.sh/rebuild.sh append it to the output name they build.
      profiles = [
        { suffix = ""; usePersonalSetup = true; }
        { suffix = "-basic"; usePersonalSetup = false; }
      ];
      setups = builtins.concatMap (p: [
        (p // { blockchainDev = false; })
        (p // { suffix = "${p.suffix}-blockchain"; blockchainDev = true; })
      ]) profiles;
      # Ubuntu 22.04 has no nix-darwin equivalent, so its path is standalone
      # home-manager (below) instead of a darwinConfigurations-style system
      # config: no root, no sudo, no Homebrew.
      linuxSystems = [ "x86_64-linux" "aarch64-linux" ];

      mkDarwin = { usePersonalSetup, blockchainDev, ... }: nix-darwin.lib.darwinSystem {
        specialArgs = { inherit user usePersonalSetup blockchainDev; };
        modules = [
          ./configuration.nix
          nix-homebrew.darwinModules.nix-homebrew
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "before-home-manager";
            home-manager.extraSpecialArgs = { inherit user usePersonalSetup blockchainDev; };
            home-manager.users.${user} = import ./home.nix;
          }
        ];
      };

      mkHome = system: { usePersonalSetup, blockchainDev, ... }: home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
        extraSpecialArgs = { inherit user usePersonalSetup blockchainDev; };
        modules = [ ./home.nix ];
      };
    in
    {
      # "mac", "mac-basic", "mac-blockchain", "mac-basic-blockchain".
      darwinConfigurations = builtins.listToAttrs (map (setup: {
        name = "${hostLabel}${setup.suffix}";
        value = mkDarwin setup;
      }) setups);

      # bootstrap.sh/rebuild.sh select "${user}@$(uname -m)-linux" on Ubuntu,
      # plus the same suffixes .env selects.
      homeConfigurations = builtins.listToAttrs (builtins.concatLists (map (system:
        map (setup: {
          name = "${user}@${system}${setup.suffix}";
          value = mkHome system setup;
        }) setups) linuxSystems));
    };
}
