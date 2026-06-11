{
  description = "nix system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, nix-darwin, home-manager, rust-overlay, ... }:
    let
      # ── Identity ────────────────────────────────────────────────────────────
      # Identity is loaded from user.nix (gitignored, never committed).
      # Copy user.nix.example to user.nix and fill in your values.
      # Requires --impure flag (builtins.getEnv reads HOME at eval time).
      homeDir     = builtins.getEnv "HOME";
      userNixPath = homeDir + "/.nix-config/user.nix";
      userBase    = if homeDir != "" && builtins.pathExists userNixPath
                    then import userNixPath
                    else import (self + /user.nix.example);
      user = userBase // {
        # Derive SSH key name from email prefix — key file: ~/.ssh/<sshKey>
        sshKey = builtins.elemAt (builtins.split "@" userBase.email) 0;
      };

      pkgsConfig = { allowUnfree = true; };

      # ── Helpers ──────────────────────────────────────────────────────────────
      isLinux  = s: builtins.elem s [ "x86_64-linux"  "aarch64-linux"  ];
      isDarwin = s: builtins.elem s [ "x86_64-darwin" "aarch64-darwin" ];

      # nixpkgs with rust-overlay applied
      mkPkgs = system: import nixpkgs {
        inherit system;
        config   = pkgsConfig;
        overlays = [ rust-overlay.overlays.default ];
      };

      mkSpecialArgs = system: context: { inherit system self user context; };

      # ── Profile compositor ───────────────────────────────────────────────────
      # Produces the ordered module list for a profile.
      # context : "personal" | "work"
      # tier    : "minimal" | "dev" | "server"
      # withGui : bool — gui module auto-selected from system
      mkProfile = { context, tier, withGui, system }:
        let
          tierMods = {
            minimal = [];
            dev     = [ ./modules/dev.nix ];
            server  = [ ./modules/server.nix ];
          }.${tier};

          contextMods =
            if context == "work" then [ ./modules/work.nix ] else [];

          guiMods =
            if !withGui     then []
            else if isLinux  system then [ ./modules/gui-linux.nix  ]
            else                         [ ./modules/gui-darwin.nix ];
        in
          [ ./modules/base.nix ] ++ tierMods ++ contextMods ++ guiMods;

      # ── Home Manager (standalone Linux/WSL2) ────────────────────────────────
      mkHomeConfig = { context, tier, withGui, system, ... }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = mkPkgs system;
          extraSpecialArgs = mkSpecialArgs system context;
          modules =
            (mkProfile { inherit context tier withGui system; })
            ++ [ { nixpkgs.config = pkgsConfig; } ];
        };

      # Both x86_64 and aarch64 variants for a Linux profile
      mkLinuxPair = args:
        {
          "${args.name}"         = mkHomeConfig (args // { system = "x86_64-linux";  });
          "${args.name}-aarch64" = mkHomeConfig (args // { system = "aarch64-linux"; });
        };

      # ── Darwin (nix-darwin + home-manager) ──────────────────────────────────
      # Darwin configs always include GUI; gui-darwin.nix is auto-selected.
      mkDarwinConfig = { context, system }:
        nix-darwin.lib.darwinSystem {
          inherit system;
          specialArgs = mkSpecialArgs system context;
          modules = [
            ./system/darwin.nix
            home-manager.darwinModules.home-manager
            {
              nixpkgs.config = pkgsConfig;
              home-manager.useGlobalPkgs        = true;
              home-manager.useUserPackages      = false;
              home-manager.backupFileExtension  = "bk";
              home-manager.extraSpecialArgs     = mkSpecialArgs system context;
              home-manager.users.${user.username} = {
                imports = mkProfile {
                  inherit context system;
                  tier    = "dev";
                  withGui = true;
                };
              };
            }
          ];
        };

      # ── NixOS ────────────────────────────────────────────────────────────────
      mkNixosConfig = { context, system }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = mkSpecialArgs system context;
          modules = [
            ./system/nixos.nix
            home-manager.nixosModules.home-manager
            {
              nixpkgs.config = pkgsConfig;
              home-manager.useGlobalPkgs        = true;
              home-manager.useUserPackages      = true;
              home-manager.backupFileExtension  = "bk";
              home-manager.extraSpecialArgs     = mkSpecialArgs system context;
              home-manager.users.${user.username} = {
                imports = mkProfile {
                  inherit context system;
                  tier    = "dev";
                  withGui = true;
                };
              };
            }
          ];
        };

    in {
      # ── homeConfigurations ──────────────────────────────────────────────────
      # Bootstrap: nix run home-manager -- switch --flake ~/.nix-config#<name>
      # After first apply: home-manager switch --flake ~/.nix-config#<name>
      #
      # To add a profile: add a mkLinuxPair call below and pick context/tier/withGui.
      # See modules/ for what each tier/context/gui module provides.
      homeConfigurations =
        (mkLinuxPair { name = "personal";         context = "personal"; tier = "dev";     withGui = false; }) //
        (mkLinuxPair { name = "personal-gui";     context = "personal"; tier = "dev";     withGui = true;  }) //
        (mkLinuxPair { name = "personal-minimal"; context = "personal"; tier = "minimal"; withGui = false; }) //
        (mkLinuxPair { name = "personal-server";  context = "personal"; tier = "server";  withGui = false; }) //
        (mkLinuxPair { name = "work";             context = "work";     tier = "dev";     withGui = false; }) //
        (mkLinuxPair { name = "work-gui";         context = "work";     tier = "dev";     withGui = true;  }) //
        (mkLinuxPair { name = "work-minimal";     context = "work";     tier = "minimal"; withGui = false; }) //
        (mkLinuxPair { name = "work-server";      context = "work";     tier = "server";  withGui = false; });

      # ── darwinConfigurations ────────────────────────────────────────────────
      # Bootstrap: sudo darwin-rebuild switch --flake ~/.nix-config#<name>
      darwinConfigurations = {
        "personal-darwin"         = mkDarwinConfig { context = "personal"; system = "x86_64-darwin";  };
        "personal-darwin-aarch64" = mkDarwinConfig { context = "personal"; system = "aarch64-darwin"; };
        "work-darwin"             = mkDarwinConfig { context = "work";     system = "x86_64-darwin";  };
        "work-darwin-aarch64"     = mkDarwinConfig { context = "work";     system = "aarch64-darwin"; };
      };

      # ── nixosConfigurations ─────────────────────────────────────────────────
      # Uncomment and add hardware-configuration.nix when setting up a real NixOS machine.
      # nixosConfigurations = {
      #   "personal-nixos" = mkNixosConfig { context = "personal"; system = "x86_64-linux"; };
      #   "work-nixos"     = mkNixosConfig { context = "work";     system = "x86_64-linux"; };
      # };
    };
}
