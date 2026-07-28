{
  description = "nix system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # darwinConfigurations pin a nixpkgs release branch instead of tracking
    # nixpkgs-unstable, for two independent reasons:
    #   1. nixpkgs-unstable dropped x86_64-darwin support (release notes:
    #      nixos.org/manual/nixpkgs/unstable/release-notes#x86_64-darwin-26.11).
    #   2. This is an Intel 2018 MacBook Pro capped at macOS 13 (Ventura,
    #      Darwin 22). nixpkgs 25.11-darwin and later bumped darwinMinVersion
    #      to 14.0 — their binaries link against macOS 14's libc++ (e.g.
    #      std::pmr symbols) and abort under dyld on macOS 13. 25.05-darwin is
    #      the newest release still targeting macOS <=13 (darwinMinVersion
    #      11.3) AND still supporting x86_64-darwin, so it is the ceiling for
    #      this machine.
    # Tradeoff: 25.05 is past its upstream security-support window. The
    # binding constraint is the OS (can't upgrade a 2018 Intel Mac past
    # Ventura), not security recency — revisit only if the machine is replaced
    # or moved to NixOS. Crucially, BOTH reasons above are specific to
    # x86_64-darwin: aarch64-darwin (Apple Silicon) is a first-class platform
    # on nixpkgs-unstable AND runs current macOS, so it has neither problem.
    # This pin therefore applies to x86_64-darwin ONLY; aarch64-darwin tracks
    # the rolling nixpkgs/home-manager/nix-darwin inputs, same as Linux (the
    # arch split lives in mkDarwinConfig below). Every Linux/WSL2 profile also
    # stays on rolling nixpkgs-unstable above.
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-25.05-darwin";
    # nix-darwin enforces that its release branch and its nixpkgs input's
    # release branch correspond (master pairs with nixpkgs-unstable;
    # nix-darwin-YY.MM pairs with nixpkgs-YY.MM-darwin). We carry two, one per
    # darwin pair: nix-darwin (master) for aarch64-darwin, nix-darwin-x86
    # (25.05) for x86_64-darwin.
    nix-darwin.url = "github:nix-darwin/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-darwin-x86.url = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
    nix-darwin-x86.inputs.nixpkgs.follows = "nixpkgs-darwin";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # x86_64-darwin builds against pinned nixpkgs-25.05-darwin, so it needs the
    # matching home-manager release branch. Home Manager's module code is
    # coupled to its nixpkgs release: the master branch's
    # `home-manager-applications` passes a bare "/Applications" string to
    # buildEnv, which the pinned nixpkgs release's stricter builder rejects
    # (it expects a list). Mirrors the nix-darwin release-correspondence
    # pairing above. Also lines up with home.stateVersion = "25.05".
    # (aarch64-darwin uses the rolling `home-manager` input above.)
    home-manager-darwin = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-darwin,
    nix-darwin,
    nix-darwin-x86,
    home-manager,
    home-manager-darwin,
    rust-overlay,
    ...
  }: let
    # ── Identity ────────────────────────────────────────────────────────────
    # Identity is loaded from user.nix (gitignored, never committed).
    # Copy user.nix.example to user.nix and fill in your values.
    # builtins.getEnv is impure (value varies per eval), so all home-manager
    # switch calls require --impure. Alternatives (absolute path, sops-nix)
    # trade portability or simplicity — see docs for tradeoff discussion.
    #
    # Default location is $HOME/.nix-config/user.nix. If you've cloned this
    # repo somewhere else, set NIX_CONFIG_USER_FILE to the full path of your
    # user.nix instead of relying on the default.
    homeDir = builtins.getEnv "HOME";
    # SUDO_USER is set by sudo to the invoking (real) user. `sudo
    # darwin-rebuild switch` / `sudo nixos-rebuild switch` reset $HOME to
    # root's home (/var/root), so getEnv "HOME" alone would miss the real
    # user.nix and silently fall back to user.nix.example (username
    # "yourusername") — which then fails activation on `system.primaryUser`.
    # Fall back to the invoking user's home in that case, trying both the
    # darwin (/Users) and Linux (/home) prefixes rather than probing the
    # eval system. First existing candidate wins.
    sudoUser = builtins.getEnv "SUDO_USER";
    userNixPathOverride = builtins.getEnv "NIX_CONFIG_USER_FILE";
    userNixCandidates =
      nixpkgs.lib.optional (userNixPathOverride != "") userNixPathOverride
      ++ nixpkgs.lib.optional (homeDir != "") (homeDir + "/.nix-config/user.nix")
      ++ nixpkgs.lib.optionals (sudoUser != "") [
        "/Users/${sudoUser}/.nix-config/user.nix"
        "/home/${sudoUser}/.nix-config/user.nix"
      ];
    existingUserNix = builtins.filter builtins.pathExists userNixCandidates;
    userBase =
      if userNixPathOverride != ""
      then
        # Explicitly set: a typo'd path is a real mistake, not a fresh
        # checkout that hasn't created user.nix yet — fail loudly instead of
        # silently building with the placeholder identity.
        (
          if builtins.pathExists userNixPathOverride
          then import userNixPathOverride
          else throw "NIX_CONFIG_USER_FILE=${userNixPathOverride} does not exist"
        )
      else if existingUserNix != []
      then import (builtins.head existingUserNix)
      else import (self + /user.nix.example);
    user =
      userBase
      // {
        # Derive SSH key name from email prefix — key file: ~/.ssh/<sshKey>
        sshKey = builtins.elemAt (builtins.split "@" userBase.email) 0;
      };

    pkgsConfig = {allowUnfree = true;};

    # ── Release pairing guard ────────────────────────────────────────────────
    # Home Manager's module code is coupled to its nixpkgs release: a mismatched
    # pair evaluates but emits deprecation warnings and can silently generate
    # wrong config (HM itself only warns, via home.enableNixpkgsReleaseCheck).
    # This repo maintains two independent pairs — rolling (Linux/WSL2) and
    # pinned (darwin) — so a `nix flake update <one-input>` can desync either
    # one. That is exactly what happened: nixpkgs was bumped to 26.11 while
    # home-manager stayed on a 25.11-era master revision for ~10 months.
    #
    # Fail evaluation instead of warning, so drift can't be ignored. To fix a
    # failure here, update BOTH inputs of the offending pair together (`just
    # update`, which never updates a single input).
    hmRelease = hm: (builtins.fromJSON (builtins.readFile (hm + "/release.json"))).release;
    checkReleasePair = label: hm: npkgs: let
      hmVer = hmRelease hm;
      npkgsVer = npkgs.lib.trivial.release;
    in
      nixpkgs.lib.throwIf (hmVer != npkgsVer) ''
        ${label}: home-manager (${hmVer}) and nixpkgs (${npkgsVer}) releases disagree.

        Home Manager modules are coupled to their nixpkgs release; a mismatched
        pair produces deprecation warnings and can generate incorrect config.

        Fix: update both inputs of this pair together — `just update`.
      ''
      true;

    # Evaluated by every config output below (see mkHomeConfig / mkDarwinConfig).
    # The rolling pair (nixpkgs + home-manager master) backs Linux/WSL2 AND
    # aarch64-darwin; the pinned pair backs x86_64-darwin only.
    linuxPairOk = checkReleasePair "rolling (Linux/WSL2 + aarch64-darwin)" home-manager nixpkgs;
    darwinPairOk = checkReleasePair "x86_64-darwin (pinned)" home-manager-darwin nixpkgs-darwin;

    # ── Helpers ──────────────────────────────────────────────────────────────
    isLinux = s: builtins.elem s ["x86_64-linux" "aarch64-linux"];
    # Only x86_64-darwin uses the pinned 25.05 darwin inputs (see input
    # comment). aarch64-darwin rides the rolling inputs, same as Linux.
    isX86Darwin = s: s == "x86_64-darwin";

    # nixpkgs with rust-overlay applied
    mkPkgs = system:
      import nixpkgs {
        inherit system;
        config = pkgsConfig;
        overlays = [rust-overlay.overlays.default];
      };

    # x86_64-darwin uses the pinned nixpkgs-darwin input (see the flake input
    # comment above for why), not the rolling nixpkgs-unstable used everywhere
    # else — including aarch64-darwin.
    mkPkgsDarwin = system:
      import nixpkgs-darwin {
        inherit system;
        config = pkgsConfig;
        overlays = [rust-overlay.overlays.default];
      };

    # Right package set for any system: pinned nixpkgs-darwin for x86_64-darwin,
    # rolling nixpkgs for everything else (Linux + aarch64-darwin).
    pkgsFor = system:
      if isX86Darwin system
      then mkPkgsDarwin system
      else mkPkgs system;

    # context and user are threaded into all modules via specialArgs so modules
    # can gate features (work.nix inclusion, copilot symlink, CLAUDE_PROFILE) on them.
    mkSpecialArgs = system: context: {inherit system self user context;};

    # ── Profile compositor ────────────────────────────────────────────────────
    # Produces the ordered module list for a profile.
    # context : "personal" | "work"
    # tier    : "minimal" | "dev" | "server"
    # withGui : bool — gui module auto-selected from system
    mkProfile = {
      context,
      tier,
      withGui,
      system,
    }: let
      tierMods =
        {
          minimal = [];
          dev = [./modules/dev.nix];
          server = [./modules/server.nix];
        }.${
          tier
        };

      contextMods =
        if context == "work"
        then [./modules/work.nix]
        else [];

      guiMods =
        if !withGui
        then []
        else if isLinux system
        then [./modules/gui-linux.nix]
        else [./modules/gui-darwin.nix];
    in
      [./modules/base.nix ./modules/env.nix] ++ tierMods ++ contextMods ++ guiMods;

    # ── Home Manager (standalone Linux/WSL2) ────────────────────────────────
    mkHomeConfig = {
      context,
      tier,
      withGui,
      system,
      ...
    }:
    # assert forces the release-pair check before any config is built.
      assert linuxPairOk;
        home-manager.lib.homeManagerConfiguration {
          pkgs = mkPkgs system;
          extraSpecialArgs = mkSpecialArgs system context;
          modules =
            (mkProfile {inherit context tier withGui system;})
            ++ [{nixpkgs.config = pkgsConfig;}];
        };

    # Both x86_64 and aarch64 variants for a Linux profile
    mkLinuxPair = args: {
      "${args.name}" = mkHomeConfig (args // {system = "x86_64-linux";});
      "${args.name}-aarch64" = mkHomeConfig (args // {system = "aarch64-linux";});
    };

    # ── Darwin (nix-darwin + home-manager) ──────────────────────────────────
    # Darwin always includes GUI — nix-darwin implies a graphical macOS environment.
    # Linux profiles use withGui to opt in; macOS never runs headless via nix-darwin.
    mkDarwinConfig = {
      context,
      system,
    }: let
      # x86_64-darwin rides the pinned 25.05 trio (nixpkgs-darwin +
      # nix-darwin-x86 + home-manager-darwin); aarch64-darwin rides the rolling
      # trio (nixpkgs + nix-darwin + home-manager), same inputs as Linux. Each
      # nix-darwin/home-manager must match its nixpkgs release, so all three
      # move together per arch.
      x86 = isX86Darwin system;
      darwinLib =
        if x86
        then nix-darwin-x86
        else nix-darwin;
      hmModule =
        if x86
        then home-manager-darwin.darwinModules.home-manager
        else home-manager.darwinModules.home-manager;
      # assert forces the matching release-pair check before any config builds.
      pairOk =
        if x86
        then darwinPairOk
        else linuxPairOk;
    in
      assert pairOk;
        darwinLib.lib.darwinSystem {
          inherit system;
          specialArgs = mkSpecialArgs system context;
          modules = [
            ./system/darwin.nix
            hmModule
            {
              nixpkgs.pkgs = pkgsFor system;
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = false;
                backupFileExtension = "bk";
                extraSpecialArgs = mkSpecialArgs system context;
                users.${user.username} = {
                  imports = mkProfile {
                    inherit context system;
                    tier = "dev";
                    withGui = true;
                  };
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
      (mkLinuxPair {
        name = "personal";
        context = "personal";
        tier = "dev";
        withGui = false;
      })
      // (mkLinuxPair {
        name = "personal-gui";
        context = "personal";
        tier = "dev";
        withGui = true;
      })
      // (mkLinuxPair {
        name = "personal-minimal";
        context = "personal";
        tier = "minimal";
        withGui = false;
      })
      // (mkLinuxPair {
        name = "personal-server";
        context = "personal";
        tier = "server";
        withGui = false;
      })
      // (mkLinuxPair {
        name = "work";
        context = "work";
        tier = "dev";
        withGui = false;
      })
      // (mkLinuxPair {
        name = "work-gui";
        context = "work";
        tier = "dev";
        withGui = true;
      })
      // (mkLinuxPair {
        name = "work-minimal";
        context = "work";
        tier = "minimal";
        withGui = false;
      })
      // (mkLinuxPair {
        name = "work-server";
        context = "work";
        tier = "server";
        withGui = false;
      });

    # ── darwinConfigurations ────────────────────────────────────────────────
    # Bootstrap: sudo darwin-rebuild switch --flake ~/.nix-config#<name>
    darwinConfigurations = {
      "personal-darwin" = mkDarwinConfig {
        context = "personal";
        system = "x86_64-darwin";
      };
      "personal-darwin-aarch64" = mkDarwinConfig {
        context = "personal";
        system = "aarch64-darwin";
      };
      "work-darwin" = mkDarwinConfig {
        context = "work";
        system = "x86_64-darwin";
      };
      "work-darwin-aarch64" = mkDarwinConfig {
        context = "work";
        system = "aarch64-darwin";
      };
    };

    # ── nixosConfigurations ─────────────────────────────────────────────────
    # NixOS support is tracked in issue #5. Requires hardware-configuration.nix
    # and a mkNixosConfig helper (analogous to mkDarwinConfig above).

    # ── devShells ────────────────────────────────────────────────────────────
    # `nix develop` — lint tools for contributors (matches .pre-commit-config.yaml
    # and CI's lint-* jobs) plus a nightly Rust toolchain, so `rustup` is never
    # needed alongside rust-overlay's stable default (avoids two cargo/rustc on
    # PATH).
    devShells =
      nixpkgs.lib.genAttrs
      ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"]
      (system: let
        pkgs = pkgsFor system;
      in {
        default = pkgs.mkShell {
          packages = with pkgs; [
            alejandra
            statix
            deadnix
            markdownlint-cli
            pre-commit
          ];
        };
        rust-nightly = pkgs.mkShell {
          packages = [
            (pkgs.rust-bin.nightly.latest.default.override {
              extensions = ["rust-src" "rustfmt" "clippy"];
            })
          ];
        };
      });

    # ── formatter ────────────────────────────────────────────────────────────
    # `nix fmt` — alejandra, matching .pre-commit-config.yaml and CI's
    # lint-alejandra job so all three (editor, pre-commit, CI) agree.
    formatter =
      nixpkgs.lib.genAttrs
      ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"]
      (system: (pkgsFor system).alejandra);

    # ── checks ───────────────────────────────────────────────────────────────
    # `nix flake check` — previously eval-only (see docs/troubleshooting.md
    # history); this makes it build every Linux activation package and run the
    # same lints CI runs, so a green `just check` actually means something
    # locally, not just "the flake evaluates." Scoped to Linux only: on
    # x86_64-darwin/aarch64-darwin, `nix flake check --impure` silently skips
    # `checks` entirely rather than building anything (no local Linux builder
    # to build these against) — a green check on a Mac isn't this check
    # running, it's this check not running at all. Real Darwin verification
    # happens in CI or on an actual Mac.
    checks = nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux"] (
      system: let
        pkgs = mkPkgs system;
        homeConfigsForSystem =
          nixpkgs.lib.filterAttrs
          (
            _: cfg:
              cfg.activationPackage.system or null == system
          )
          self.homeConfigurations;
      in
        (nixpkgs.lib.mapAttrs'
          (name: cfg: {
            name = "activation-${name}";
            value = cfg.activationPackage;
          })
          homeConfigsForSystem)
        // {
          alejandra = pkgs.runCommand "check-alejandra" {} ''
            ${pkgs.alejandra}/bin/alejandra --check ${self}
            touch $out
          '';
          statix = pkgs.runCommand "check-statix" {} ''
            ${pkgs.statix}/bin/statix check ${self}
            touch $out
          '';
          deadnix = pkgs.runCommand "check-deadnix" {} ''
            ${pkgs.deadnix}/bin/deadnix --fail ${self}
            touch $out
          '';
          # A relative glob after cd, not an absolute-path glob string: this
          # markdownlint-cli version resolves those two differently (same
          # class of discrepancy already seen with deadnix elsewhere in this
          # repo's history) and only the relative form reliably matches the
          # files CI's own lint-markdownlint job lints.
          markdownlint = pkgs.runCommand "check-markdownlint" {} ''
            cd ${self}
            ${pkgs.markdownlint-cli}/bin/markdownlint 'docs/**/*.md' README.md CONTRIBUTING.md CLAUDE.md
            touch $out
          '';
        }
    );
  };
}
