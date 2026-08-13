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
    #      to 14.0: their binaries link against macOS 14's libc++ (e.g.
    #      std::pmr symbols) and abort under dyld on macOS 13. 25.05-darwin is
    #      the newest release still targeting macOS <=13 (darwinMinVersion
    #      11.3) AND still supporting x86_64-darwin, so it is the ceiling for
    #      this machine.
    # Tradeoff: 25.05 is past its upstream security-support window. The
    # binding constraint is the OS (can't upgrade a 2018 Intel Mac past
    # Ventura), not security recency: revisit only if the machine is replaced
    # or moved to NixOS. Crucially, BOTH reasons above are specific to
    # x86_64-darwin: aarch64-darwin (Apple Silicon) is a first-class platform
    # on nixpkgs-unstable AND runs current macOS, so it has neither problem.
    # This pin therefore applies to x86_64-darwin ONLY; aarch64-darwin tracks
    # the rolling nixpkgs/home-manager/nix-darwin inputs, same as Linux (the
    # arch split lives in lib/systems.nix). Every Linux/WSL2 profile also
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
    # follows nixpkgs-darwin (not nixpkgs) so caret's trivial file-copy
    # derivation still builds on x86_64-darwin, which rolling nixpkgs-unstable
    # has dropped; this pins caret's nixpkgs for every system, but caret has
    # no real version dependency so that's harmless.
    caret = {
      url = "github:cdprice02/caret";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
    # Only ever imported when a machine's user.nix sets sopsFile; see
    # mkProfile's sopsMods below. Follows nixpkgs (not nixpkgs-darwin):
    # unlike caret, sops-nix has no x86_64-darwin-specific build concern, so
    # it doesn't need the same override.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Follows nixpkgs-darwin (not rolling nixpkgs), deliberately, on every
    # system including the three that aren't x86_64-darwin. The instinct is
    # "use rolling everywhere for the freshest formatter" -- checked
    # directly and that's not actually available: rolling nixpkgs-unstable
    # has dropped x86_64-darwin support entirely (`nixpkgs.legacyPackages.
    # x86_64-darwin` throws, matching the same platform-support cliff this
    # flake's own nixpkgs-darwin input comment already documents for every
    # other package). nixpkgs-darwin is a real, ordinary nixpkgs branch that
    # happens to also support x86_64-darwin -- its legacyPackages resolves
    # for every system this flake targets (confirmed directly), all
    # reporting the identical nixfmt-rfc-style 1.1.0, vs. rolling's 1.4.0
    # which differs materially in output. One pin, every system, genuinely
    # uniform formatting -- not the newest release, but consistency is the
    # actual goal here, and "newest" was never achievable for all four
    # systems at once regardless of which input is chosen.
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
    # home-manager's own module test framework (see tests/nmt/harness.nix).
    # Test-only, no runtime footprint in any real config, but a real flake
    # input rather than a hand-pinned fetchTarball so it rides `just update`
    # and Dependabot's lock-file visibility the same as everything else this
    # framework depends on. Has no flake.nix of its own (confirmed directly),
    # so flake = false; pinned to its v0.5.1 tag, the same release the
    # previous fetchTarball pin used.
    nmt = {
      url = "git+https://git.sr.ht/~rycee/nmt?ref=v0.5.1";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-darwin,
      nix-darwin,
      nix-darwin-x86,
      home-manager,
      home-manager-darwin,
      rust-overlay,
      caret,
      sops-nix,
      treefmt-nix,
      nmt,
      ...
    }:
    let
      # ── Identity ────────────────────────────────────────────────────────────
      # Identity is loaded from user.nix (gitignored, never committed).
      # Copy user.nix.example to user.nix and fill in your values.
      # builtins.getEnv is impure (value varies per eval), so all home-manager
      # switch calls require --impure. Alternatives (a hardcoded absolute path,
      # sops-nix) trade portability or simplicity for that impurity.
      #
      # Default location is $HOME/.nix-atelier/user.nix. If you've cloned this
      # repo somewhere else, set NIX_CONFIG_USER_FILE to the full path of your
      # user.nix instead of relying on the default.
      homeDir = builtins.getEnv "HOME";
      # SUDO_USER is set by sudo to the invoking (real) user. `sudo
      # darwin-rebuild switch` / `sudo nixos-rebuild switch` reset $HOME to
      # root's home (/var/root), so getEnv "HOME" alone would miss the real
      # user.nix and silently fall back to user.nix.example (username
      # "yourusername"): which then fails activation on `system.primaryUser`.
      # Fall back to the invoking user's home in that case, trying both the
      # darwin (/Users) and Linux (/home) prefixes rather than probing the
      # eval system. First existing candidate wins.
      sudoUser = builtins.getEnv "SUDO_USER";
      userNixPathOverride = builtins.getEnv "NIX_CONFIG_USER_FILE";
      userNixCandidates =
        nixpkgs.lib.optional (userNixPathOverride != "") userNixPathOverride
        ++ nixpkgs.lib.optional (homeDir != "") (homeDir + "/.nix-atelier/user.nix")
        ++ nixpkgs.lib.optionals (sudoUser != "") [
          "/Users/${sudoUser}/.nix-atelier/user.nix"
          "/home/${sudoUser}/.nix-atelier/user.nix"
        ];
      existingUserNix = builtins.filter builtins.pathExists userNixCandidates;
      userBase =
        if userNixPathOverride != "" then
          # Explicitly set: a typo'd path is a real mistake, not a fresh
          # checkout that hasn't created user.nix yet: fail loudly instead of
          # silently building with the placeholder identity.
          (
            if builtins.pathExists userNixPathOverride then
              import userNixPathOverride
            else
              throw "NIX_CONFIG_USER_FILE=${userNixPathOverride} does not exist"
          )
        else if existingUserNix != [ ] then
          import (builtins.head existingUserNix)
        else
          import (self + /user.nix.example);
      # ── Systems ────────────────────────────────────────────────────────────
      # Which of the two release pairs a system uses, and the resolved
      # pkgs/home-manager/nix-darwin for it: one cohesive unit (lib/systems.nix)
      # instead of half a dozen separate bindings, shared between this file's
      # own (still impure) config construction below and lib/mkConfigs.nix
      # (#122). Fails evaluation on a release-pair mismatch rather than
      # warning (HM's own home.enableNixpkgsReleaseCheck only warns, which is
      # easy to miss); update both inputs of the offending pair together
      # (`just update`, which never updates a single input).
      systemsLib = import ./lib/systems.nix {
        inherit
          nixpkgs
          nixpkgs-darwin
          home-manager
          home-manager-darwin
          nix-darwin
          nix-darwin-x86
          rust-overlay
          ;
      };
      inherit (systemsLib)
        allSystems
        isLinux
        isX86Darwin
        pkgsFor
        ;

      # user is threaded into every module via specialArgs. mkUser lives in
      # lib/mkConfigs.nix (#122) rather than here: it has no real dependency
      # on this file beyond a source location, and the nmt harness's testUser
      # goes through the same derivation.
      user = mkConfigsLib.mkUser userBase;

      # Deliberately nixpkgs-darwin.legacyPackages on every system, not
      # pkgsFor (which would only route x86_64-darwin there and everything
      # else to rolling nixpkgs, reintroducing the version skew) and not
      # rolling nixpkgs.legacyPackages either (unavailable for x86_64-darwin
      # at all -- see the treefmt-nix flake input's own comment). One pin,
      # every system, so `nix fmt`'s output doesn't depend on which machine
      # ran it.
      treefmtEval = nixpkgs.lib.genAttrs allSystems (
        system: treefmt-nix.lib.evalModule nixpkgs-darwin.legacyPackages.${system} ./treefmt.nix
      );

      # ── Feature/tier data model ────────────────────────────────────────────────
      # features.nix: name -> module path registry. core/env aren't in it: they're
      # an always-on prefix mkProfile adds unconditionally, not a selectable
      # feature. Both tiers are derived from that same registry, so a new feature
      # joins `full` automatically and there is no second list to keep in sync.
      features = import ./modules/features.nix;
      tiers = {
        minimal = [ ];
        full = builtins.attrNames features;
      };
      toolCatalog = import ./modules/tool-catalog.nix;

      # A features.nix entry is either a bare path or an attrset
      # { module; unsupported; } (see that file's own comment). These two
      # accessors are the only place that shape distinction is unwrapped.
      featureModule = f: if builtins.isAttrs f then f.module else f;
      featureUnsupported = f: if builtins.isAttrs f then (f.unsupported or [ ]) else [ ];

      # ── Docs generation ────────────────────────────────────────────────────
      # Realized package identities (p.pname or p.name) across every already-
      # built home/darwin/nixos config: reuses the actual mkProfile composition
      # rather than statically re-scanning modules/features/*.nix, so it also
      # catches packages home-manager's own program modules inject implicitly
      # (e.g. programs.git.delta.enable -> the delta package, with no
      # home.packages entry anywhere in this repo).
      installedPackageNames =
        let
          pkgIdent = p: p.pname or p.name;
          homePkgLists = map (cfg: cfg.config.home.packages) (builtins.attrValues self.homeConfigurations);
          darwinPkgLists = map (cfg: cfg.config.home-manager.users.${user.username}.home.packages) (
            builtins.attrValues self.darwinConfigurations
          );
          # Same shape as darwin: nixosSystem also nests Home Manager under
          # home-manager.users.<username>, not home.packages directly.
          nixosPkgLists = map (cfg: cfg.config.home-manager.users.${user.username}.home.packages) (
            builtins.attrValues self.nixosConfigurations
          );
        in
        nixpkgs.lib.unique (
          map pkgIdent (nixpkgs.lib.flatten (homePkgLists ++ darwinPkgLists ++ nixosPkgLists))
        );

      # Bidirectional: every installed package needs a tool-catalog.nix entry
      # (or an explicit exclusion), and every catalog entry needs to actually
      # correspond to something installed: fail eval rather than let the two
      # drift silently.
      catalogedNames = nixpkgs.lib.concatMap (e: e.matches) toolCatalog.entries;
      uncatalogedInstalled = nixpkgs.lib.subtractLists (
        catalogedNames ++ toolCatalog.infraExclude
      ) installedPackageNames;
      staleCatalogEntries = nixpkgs.lib.subtractLists installedPackageNames catalogedNames;
      docsCatalogValid =
        nixpkgs.lib.throwIf (uncatalogedInstalled != [ ])
          "modules/tool-catalog.nix is missing entries for installed packages: ${toString uncatalogedInstalled}"
          (
            nixpkgs.lib.throwIf (staleCatalogEntries != [ ])
              "modules/tool-catalog.nix has entries for packages that aren't installed anywhere: ${toString staleCatalogEntries}"
              true
          );

      docsGenerated = (import ./modules/docs-gen.nix { inherit (nixpkgs) lib; }) {
        inherit tiers toolCatalog;
        homeConfigNames = builtins.attrNames self.homeConfigurations;
        darwinConfigNames = builtins.attrNames self.darwinConfigurations;
      };

      # ── Profile compositor ────────────────────────────────────────────────────
      # Produces the ordered module list for a profile.
      # tier    : "minimal" | "full"
      # withGui : bool: gui module auto-selected from system
      # userData / featuresOverride default to the real top-level `user` /
      # `features` bindings, so every real call site (home/darwin configs) below
      # is unaffected. The nmt harness overrides both: userData so its fixture is
      # genuinely identity-independent (previously it silently read whichever
      # real user.nix happened to be on the evaluating machine -- harmless today
      # only because this machine's extraFeatures/excludeFeatures/
      # extraModulePaths happen to be empty, but a contributor with a private
      # extraModulePaths entry would have had it evaluated into `nix flake
      # check`), and featuresOverride so the platform-filtering check
      # (feature-platform-filtering below) can exercise a synthetic unsupported
      # feature without adding test-only noise to the real, shipped registry.
      mkProfile =
        {
          tier,
          withGui,
          system,
          userData ? user,
          featuresOverride ? features,
        }:
        let
          resolveFeature =
            name:
            featuresOverride.${name} or (throw ''
              unknown feature "${name}": valid features: ${builtins.concatStringsSep ", " (builtins.attrNames featuresOverride)}
            '');
          # Tier defaults plus user.nix's extraFeatures, deduplicated (a name in
          # both is not an error: the module system already dedupes imports by
          # file, so this has always been silently fine -- unique here just
          # avoids resolving the same name twice). excludeFeatures is the
          # inverse escape hatch: names to drop regardless of where they came
          # from, and also how a machine silences the unsupported-platform
          # warning below for a feature it was never going to use anyway.
          requestedNames = nixpkgs.lib.unique (
            (tiers.${tier} or (throw "unknown tier \"${tier}\"")) ++ (userData.extraFeatures or [ ])
          );
          keptNames = nixpkgs.lib.subtractLists (userData.excludeFeatures or [ ]) requestedNames;

          supportedOn = name: !(builtins.elem system (featureUnsupported (resolveFeature name)));
          usableNames = builtins.filter supportedOn keptNames;
          skippedNames = builtins.filter (n: !(supportedOn n)) keptNames;

          featureMods = map (n: featureModule (resolveFeature n)) usableNames;

          # Absolute paths to private, machine-specific modules outside this
          # repo: a string absolute path imports to a real module, and relative
          # imports inside it resolve against the real filesystem, the same
          # --impure trick user.nix itself relies on. See examples/private-config/
          # for a worked example. Empty by default.
          privateMods = map import (userData.extraModulePaths or [ ]);

          guiMods =
            if !withGui then
              [ ]
            else if isLinux system then
              [ ./modules/gui-linux.nix ]
            else
              [ ./modules/gui-darwin.nix ];

          # Bridges userData's flat aws/nativeInstallers/configRepos/sopsFile/
          # secrets fields (this repo's still-impure user.nix shape, and the
          # nmt harness's testUser) onto machine.nix's atelier.* options
          # (#120). lib.mkDefault, not a plain assignment: a mkConfigs (#122)
          # caller's own extraConfig setting the same option is a real,
          # higher-priority definition and must win outright rather than
          # conflicting with this fallback.
          machineBridge = {
            atelier = {
              aws.profile = nixpkgs.lib.mkDefault (userData.aws.profile or null);
              nativeInstallers = nixpkgs.lib.mkDefault (userData.nativeInstallers or [ ]);
              configRepos = nixpkgs.lib.mkDefault (userData.configRepos or { });
              sops = {
                file = nixpkgs.lib.mkDefault (userData.sopsFile or null);
                secrets = nixpkgs.lib.mkDefault (userData.secrets or [ ]);
              };
              submodules = nixpkgs.lib.mkDefault (userData.submodules or { });
            };
          };
        in
        nixpkgs.lib.warnIf (skippedNames != [ ])
          ''
            Skipping features unsupported on ${system}: ${nixpkgs.lib.concatStringsSep ", " skippedNames}.
            Add them to excludeFeatures in user.nix to silence this.
          ''
          (
            [
              ./modules/base.nix
              ./modules/env.nix
              ./modules/machine.nix
              sops-nix.homeManagerModules.sops
              ./modules/secrets-sops.nix
              caret.homeManagerModules.default
              machineBridge
            ]
            ++ featureMods
            ++ privateMods
            ++ guiMods
          );

      # ── mkConfigs (#122) ─────────────────────────────────────────────────────
      # The pure, consumable entry point: see lib/mkConfigs.nix for the schema
      # and per-kind builders. This repo's own homeConfigurations/
      # darwinConfigurations further down are built through it too (see
      # "This repo's own configs" below): the real proof it works standalone
      # is this repo depending on it for its own real configs, not a
      # special-cased internal path that merely looks similar. Only identity
      # loading (userBase, just below) stays impure; that removal is --impure
      # removal's own, separate PR.
      mkConfigsLib = import ./lib/mkConfigs.nix {
        inherit (nixpkgs) lib;
        systems = systemsLib;
        inherit mkProfile;
      };

      # ── Test harness (nmt) ───────────────────────────────────────────────────
      # See tests/nmt/harness.nix for the harness itself (#117): scrubbed,
      # build-free module composition plus the nmt test-runner wiring. Only
      # testUser and mkNmtTests cross back into this file; the rest
      # (nmtSrc, scrubDerivation, mustStayReal, mkScrubbedPkgs,
      # hmInputFor/hmModulesFor/hmLibFor, mkNmtModules itself) stays internal
      # to the harness -- mkNmtModules is only ever called from mkNmtTests.
      nmtHarness = import ./tests/nmt/harness.nix {
        inherit
          self
          nixpkgs
          home-manager
          home-manager-darwin
          nmt
          isX86Darwin
          pkgsFor
          mkProfile
          installedPackageNames
          ;
        inherit (mkConfigsLib) mkUser;
      };
      inherit (nmtHarness) testUser mkNmtTests;

      # ── This repo's own configs, through mkConfigs (#122) ───────────────────
      # This repo is the first real caller of its own lib.mkConfigs, not a
      # special-cased internal path: the matrix generation below (tier x gui
      # x arch for home, the two darwin arches) is this repo's own
      # convenience for dogfooding every combination, kept exactly as before;
      # what changed is that the resulting configs attrset is handed to the
      # same mkConfigs everyone else calls, instead of built by a separate,
      # parallel mkHomeConfig/mkDarwinConfig.
      #
      # aws/nativeInstallers/configRepos/sops/submodules aren't in mkConfigs's
      # schema (see machine.nix, #120): every config below carries them
      # through its own extraConfig instead, translated once here from
      # user.nix's flat shape. Identical in spirit to mkProfile's own
      # machineBridge, but a plain value, not mkDefault: extraConfig entries
      # are already the real, single definition for this repo's own configs,
      # nothing else could override them.
      atelierExtraConfig = {
        atelier = {
          aws.profile = userBase.aws.profile or null;
          nativeInstallers = userBase.nativeInstallers or [ ];
          configRepos = userBase.configRepos or { };
          sops = {
            file = userBase.sopsFile or null;
            secrets = userBase.secrets or [ ];
          };
          submodules = userBase.submodules or { };
        };
      };

      linuxArches = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      mkHomeConfigName =
        tierName: withGui: arch:
        tierName
        + (nixpkgs.lib.optionalString withGui "-gui")
        + (nixpkgs.lib.optionalString (arch == "aarch64-linux") "-aarch64");
      homeConfigsAttrs = builtins.listToAttrs (
        nixpkgs.lib.concatMap (
          tierName:
          nixpkgs.lib.concatMap
            (
              withGui:
              map (arch: {
                name = mkHomeConfigName tierName withGui arch;
                value = {
                  tier = tierName;
                  inherit withGui;
                  system = arch;
                  extraConfig = atelierExtraConfig;
                };
              }) linuxArches
            )
            [
              false
              true
            ]
        ) (builtins.attrNames tiers)
      );

      # Darwin always includes GUI: nix-darwin implies a graphical macOS
      # environment, and it's always the `full` tier -- a headless or minimal
      # Mac isn't a real use case this repo targets. mkConfigs's own darwin
      # kind already defaults to this; the entries below only need `system`.
      darwinConfigsAttrs = {
        "full-darwin" = {
          system = "x86_64-darwin";
          extraConfig = atelierExtraConfig;
        };
        "full-darwin-aarch64" = {
          system = "aarch64-darwin";
          extraConfig = atelierExtraConfig;
        };
      };

      # Ships build-verified only (#5): there's no NixOS hardware in this
      # loop to run a real `nixos-rebuild switch` end to end. hardwareModule
      # points at a synthetic fixture (sibling to the nmt fixtures) with just
      # enough (fileSystems."/", a grub device) for system.build.toplevel to
      # evaluate and build; it is never meant to boot anything. A real
      # consumer calling lib.mkConfigs points hardwareModule at their own
      # machine's real hardware-configuration.nix instead. toString, not a
      # bare path, matching extraModulePaths' own string convention -- this
      # one happens to live in-repo, but the mechanism has to work for an
      # out-of-repo, impure path too.
      nixosHardwareStub = toString ./tests/fixtures/nixos-hardware-stub.nix;
      nixosConfigsAttrs = {
        "full-nixos" = {
          system = "x86_64-linux";
          hardwareModule = nixosHardwareStub;
          extraConfig = atelierExtraConfig;
        };
        "full-nixos-aarch64" = {
          system = "aarch64-linux";
          hardwareModule = nixosHardwareStub;
          extraConfig = atelierExtraConfig;
        };
      };

      thisRepoConfigs = mkConfigsLib.mkConfigs {
        identity = {
          inherit (userBase)
            username
            name
            email
            github
            ;
        };
        configs = {
          home = homeConfigsAttrs;
          darwin = darwinConfigsAttrs;
          nixos = nixosConfigsAttrs;
        };
        features = {
          extra = userBase.extraFeatures or [ ];
          exclude = userBase.excludeFeatures or [ ];
          extraModulePaths = userBase.extraModulePaths or [ ];
          extraSystemModulePaths = userBase.extraSystemModulePaths or [ ];
        };
      };
    in
    {
      # ── lib ──────────────────────────────────────────────────────────────────
      # The consumable entry point (#122): a flake input elsewhere calls
      # `nix-atelier.lib.mkConfigs { ... }`. See lib/mkConfigs.nix.
      lib = {
        inherit (mkConfigsLib) mkConfigs;
      };

      # ── homeConfigurations ──────────────────────────────────────────────────
      # Bootstrap: nix run home-manager -- switch --flake ~/.nix-atelier#<name>
      # After first apply: home-manager switch --flake ~/.nix-atelier#<name>
      #
      # Generated from tiers x {gui,no-gui} x {x86_64,aarch64}: adding a tier or
      # a feature never means adding a name here.
      inherit (thisRepoConfigs) homeConfigurations;

      # ── darwinConfigurations ────────────────────────────────────────────────
      # Bootstrap: sudo darwin-rebuild switch --flake ~/.nix-atelier#<name>
      inherit (thisRepoConfigs) darwinConfigurations;

      # ── nixosConfigurations ─────────────────────────────────────────────────
      # Build-verified only (#5): see nixosConfigsAttrs above for why. No
      # bootstrap command here the way homeConfigurations/darwinConfigurations
      # have one -- full-nixos/full-nixos-aarch64 build against a synthetic
      # hardware fixture and were never meant to run `nixos-rebuild switch`
      # anywhere real.
      inherit (thisRepoConfigs) nixosConfigurations;

      # ── devShells ────────────────────────────────────────────────────────────
      # `nix develop`: the treefmt wrapper (nixfmt-rfc-style + statix + deadnix
      # + mdformat, see treefmt.nix) plus pre-commit, matching
      # .pre-commit-config.yaml's single treefmt hook.
      devShells = nixpkgs.lib.genAttrs allSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShell {
            packages = [
              treefmtEval.${system}.config.build.wrapper
              pkgs.pre-commit
            ];
          };
        }
      );

      # ── formatter ────────────────────────────────────────────────────────────
      # `nix fmt`: the treefmt wrapper, matching .pre-commit-config.yaml and
      # the formatting entry in `checks` below so all three (editor,
      # pre-commit, CI) agree.
      formatter = nixpkgs.lib.genAttrs allSystems (system: treefmtEval.${system}.config.build.wrapper);

      # ── packages ─────────────────────────────────────────────────────────────
      # Buildable outputs of docsGenerated, for `just docs` to copy over the
      # committed docs/*.md. docsGenerated's content is pure Nix data (no
      # platform-dependent logic), but `pkgs.writeText` still needs a matching-
      # platform builder to realize it: unlike the eval-only `checks` output,
      # this needs the full system list (same as devShells/formatter) so
      # `just docs` builds natively wherever it's run, darwin included.
      packages = nixpkgs.lib.genAttrs allSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          docs-profiles-md = pkgs.writeText "profiles.md" docsGenerated.profilesMd;
          docs-tools-md = pkgs.writeText "tools.md" docsGenerated.toolsMd;
        }
      );

      # ── checks ───────────────────────────────────────────────────────────────
      # The Nix-specific verification: nmt's assertion-level checks (rendered
      # content, GUI/headless, excludeFeatures/extraModulePaths composability,
      # per-platform feature filtering), generated-docs drift, and formatting
      # (treefmt.nix). Uniform across every system in `allSystems` -- no
      # per-platform gap, because nothing in here builds a real profile
      # closure; `build-linux`/`build-darwin` are the only things that do.
      # This is what makes a real closure build unnecessary for everyday
      # `just check` and CI's per-PR gate, on every system, not just Linux.
      checks = nixpkgs.lib.genAttrs allSystems (
        system:
        let
          # pkgsFor, not mkPkgs: mkPkgs always imports the rolling nixpkgs, which
          # has dropped x86_64-darwin, so any darwin check evaluated through it
          # dies with "Nixpkgs 26.11 has dropped support for x86_64-darwin"
          # before it can run. pkgsFor routes that one system to the pinned
          # nixpkgs-darwin input. Latent while `checks` was Linux-only.
          pkgs = pkgsFor system;
          # nmt's own `build` attrset already includes an `all` aggregate
          # (build.all), which surfaces here as nmt-all: a single check that
          # depends on every individual nmt test.
          nmtBuild =
            (mkNmtTests {
              inherit system;
              tests = import ./tests/nmt { inherit system; };
            }).build;

          # GUI variant: same harness, withGui = true instead of the default's
          # false. See tests/nmt/gui.nix and its negative counterpart
          # tests/nmt/gui-absent.nix (which runs in the default instance above,
          # no override needed there).
          guiNmtBuild =
            (mkNmtTests {
              inherit system;
              withGui = true;
              tests = import ./tests/nmt/gui.nix {
                inherit system;
                inherit (nixpkgs) lib;
              };
            }).build;

          # Composition variant: excludeFeatures and extraModulePaths together,
          # proving both actually take effect rather than merely evaluating.
          # toString on the fixture path resolves it the same way a real
          # extraModulePaths string entry would (see mkProfile's own comment on
          # userData/featuresOverride) -- no impurity, since the fixture lives
          # inside this flake's own source tree.
          compositionNmtBuild =
            (mkNmtTests {
              inherit system;
              userDataOverrides = {
                excludeFeatures = [ "tmux" ];
                extraModulePaths = [ (toString ./tests/nmt/fixtures/private-identity.nix) ];
              };
              tests = import ./tests/nmt/composition.nix;
            }).build;

          # Pure eval-level check (not nmt: this is about which modules
          # mkProfile *selects*, not what a rendered tree contains) that an
          # `unsupported`-declared feature is actually dropped on its excluded
          # system and kept everywhere else. Uses featuresOverride rather than
          # a real features.nix entry: modules/features.nix has no feature
          # with a genuine `unsupported` list right now (qmk turned out to
          # build everywhere -- see that file's own comment), and adding a
          # throwaway one there would pollute the real `full` tier for every
          # user just to exercise this one code path.
          platformFilteringFixtureFeatures = features // {
            fixture-unsupported = {
              module = ./tests/nmt/fixtures/inert-feature.nix;
              unsupported = [ system ];
            };
          };
          platformFilteringOtherSystem =
            if system == "aarch64-linux" then "x86_64-linux" else "aarch64-linux";
          platformFilteringModsFor =
            testSystem:
            mkProfile {
              tier = "minimal";
              withGui = false;
              system = testSystem;
              userData = testUser // {
                extraFeatures = [ "fixture-unsupported" ];
              };
              featuresOverride = platformFilteringFixtureFeatures;
            };
          platformFilteringDroppedOnSelf =
            !(builtins.elem ./tests/nmt/fixtures/inert-feature.nix (platformFilteringModsFor system));
          platformFilteringKeptOnOther = builtins.elem ./tests/nmt/fixtures/inert-feature.nix (
            platformFilteringModsFor platformFilteringOtherSystem
          );

          # mkConfigs (#122) proof, pure eval-level like the check above: no
          # real config gets built through here, this is entirely about the
          # schema and per-kind dispatch in lib/mkConfigs.nix.
          mkConfigsTestIdentity = {
            username = "testuser";
            name = "Test User";
            email = "test@example.com";
            github.user = "testuser";
          };

          # Valid input dispatches each kind to the right output attrset,
          # keyed by the name given: proves the configs.home/darwin/nixos
          # split actually wires through, without forcing a real build
          # (attrNames on a lib.mapAttrs result only needs the source
          # attrset's keys, not each mapped value).
          mkConfigsValid = mkConfigsLib.mkConfigs {
            identity = mkConfigsTestIdentity;
            configs.home.test.system = "x86_64-linux";
            configs.darwin.test.system = "aarch64-darwin";
          };
          mkConfigsDispatchOk =
            (builtins.attrNames mkConfigsValid.homeConfigurations == [ "test" ])
            && (builtins.attrNames mkConfigsValid.darwinConfigurations == [ "test" ])
            && (mkConfigsValid.nixosConfigurations == { });

          # A misspelled field (here "tierr") must be rejected rather than
          # silently ignored -- the actual problem #122 set out to fix.
          # builtins.deepSeq forces the whole config tree: attrNames alone
          # would only force the outer configs.home attrset's keys, not each
          # named entry's own fields, and the module system's "option does
          # not exist" check fires when a submodule's fields are resolved,
          # not when its container's key set is.
          mkConfigsTypoRejected =
            !(builtins.tryEval (
              builtins.deepSeq (mkConfigsLib.evalConfig {
                identity = mkConfigsTestIdentity;
                configs.home.test = {
                  system = "x86_64-linux";
                  tierr = "full";
                };
              }) true
            )).success;

          # A field that belongs to a different kind (tier is a home-only
          # concept) must be rejected the same way on darwin, proving the
          # configs.home/.darwin/.nixos split actually prevents cross-kind
          # leakage rather than merely documenting an intent to.
          mkConfigsCrossKindRejected =
            !(builtins.tryEval (
              builtins.deepSeq (mkConfigsLib.evalConfig {
                identity = mkConfigsTestIdentity;
                configs.darwin.test = {
                  system = "aarch64-darwin";
                  tier = "full";
                };
              }) true
            )).success;
        in
        (nixpkgs.lib.mapAttrs' (name: drv: {
          name = "nmt-${name}";
          value = drv;
        }) nmtBuild)
        // (nixpkgs.lib.mapAttrs' (name: drv: {
          name = "nmt-gui-${name}";
          value = drv;
        }) guiNmtBuild)
        // (nixpkgs.lib.mapAttrs' (name: drv: {
          name = "nmt-composition-${name}";
          value = drv;
        }) compositionNmtBuild)
        // {
          # assert docsCatalogValid forces the bidirectional catalog check
          # (see above) before this even attempts the diff, so a catalog
          # drift and a docs-content drift fail with distinct messages.
          docs-drift =
            assert docsCatalogValid;
            pkgs.runCommand "check-docs-drift" { } ''
              if ! diff -u ${./docs/profiles.md} ${pkgs.writeText "profiles.md" docsGenerated.profilesMd}; then
                echo "docs/profiles.md is out of date: run 'just docs' and commit the result"
                exit 1
              fi
              if ! diff -u ${./docs/tools.md} ${pkgs.writeText "tools.md" docsGenerated.toolsMd}; then
                echo "docs/tools.md is out of date: run 'just docs' and commit the result"
                exit 1
              fi
              touch $out
            '';

          feature-platform-filtering =
            if platformFilteringDroppedOnSelf && platformFilteringKeptOnOther then
              pkgs.runCommand "check-feature-platform-filtering" { } "touch $out"
            else
              throw ''
                feature-platform-filtering: a feature declared unsupported on
                ${system} should be dropped from that system's module list and
                kept on every other system (droppedOnSelf=${builtins.toJSON platformFilteringDroppedOnSelf}
                keptOnOther=${builtins.toJSON platformFilteringKeptOnOther}).
              '';

          mkconfigs-schema =
            if mkConfigsDispatchOk && mkConfigsTypoRejected && mkConfigsCrossKindRejected then
              pkgs.runCommand "check-mkconfigs-schema" { } "touch $out"
            else
              throw ''
                mkconfigs-schema: lib.mkConfigs's schema and dispatch aren't
                behaving as designed (dispatchOk=${builtins.toJSON mkConfigsDispatchOk}
                typoRejected=${builtins.toJSON mkConfigsTypoRejected}
                crossKindRejected=${builtins.toJSON mkConfigsCrossKindRejected}).
              '';

          formatting = treefmtEval.${system}.config.build.check self;
        }
      );
    };
}
