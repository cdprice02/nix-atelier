# The pure, consumable entry point. A plain function of a typed
# argument attrset to { homeConfigurations; darwinConfigurations;
# nixosConfigurations; }, no getEnv, no --impure.
#
# Four dependencies, each a genuinely distinct concern: `lib` (the standard
# library), `systems` (lib/systems.nix -- which of the two release pairs a
# system uses, and the resolved pkgs/home-manager/nix-darwin for it), and
# `sopsNixModule`/`caretModule` (flake inputs' own outputs, needed by
# mkProfile.nix below, which this file imports directly rather than
# receiving as an injected function -- the entry point owns its own
# compositor). Identity handling (mkUser) is self-contained here: it has no
# real dependency on flake.nix beyond a source file this module is exactly
# as close to.
#
# Deliberately does not do matrix generation (tier x gui x arch and similar):
# that is this repo's own convenience for dogfooding every combination, not
# something a consumer calling this from another flake wants imposed on them.
# A consumer names exactly the configs they want; this repo's own flake.nix
# builds its matrix the same way it always has and hands the result in here
# through the same `configs` argument everyone else uses.
{
  lib,
  systems,
  sopsNixModule,
  caretModule,
}:
let
  inherit (systems)
    allSystems
    linuxSystems
    darwinSystems
    pkgsConfig
    pkgsFor
    pairOkFor
    hmLibFor
    hmDarwinModuleFor
    darwinLibFor
    nixosHmModule
    isLinux
    ;

  # Derive SSH key name from email prefix: key file ~/.ssh/<sshKey>. Shared
  # with the nmt harness's testUser, so both go through the same derivation;
  # flake.nix's own placeholder identity imports this back out (see the
  # attrset returned at the bottom of this file) rather than keeping its own
  # copy.
  mkUser = base: base // { sshKey = builtins.elemAt (builtins.split "@" base.email) 0; };

  # The one, single definition of the tier registry and the compositor that
  # resolves it: imported here rather than each kept as a separate
  # copy the way flake.nix and this file previously did independently.
  mkProfileLib = import ./mkProfile.nix {
    inherit
      lib
      isLinux
      sopsNixModule
      caretModule
      ;
  };
  inherit (mkProfileLib) mkProfile tiers;

  # The feature-selection options, shared by the call-level `features`
  # option and each configs.<kind>.<name> entry's own `features` option, so
  # two configs in the same call can diverge -- e.g. a laptop
  # with k8s access and a WSL work machine without it, sharing one identity,
  # without splitting into two mkConfigs calls just to get there. mkConfigs'
  # own userDataFor/systemModulesFor below is what treats call-level and
  # per-config values differently (concatenation, not override).
  #
  # Two types, not one shared everywhere: extraSystemModulePaths extends
  # system/darwin.nix or system/nixos.nix, which a standalone Home Manager
  # config has no equivalent of at all, so only systemModulesFor
  # (darwin/nixos) ever reads it. Offering it on configs.home.<name> would
  # accept a field that silently does nothing there -- both the cross-kind
  # leak the configs.home/.darwin/.nixos split exists to prevent, and the
  # silent no-op this whole lib.evalModules-with-no-freeformType schema
  # exists to turn into a real error.
  homeFeaturesOptions = {
    extra = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra named features layered onto a config's tier defaults.";
    };
    exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Named features to drop regardless of tier or extra.";
    };
    extraModulePaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Absolute paths to private Home Manager modules, as strings (imported at use time; resolving a path outside the flake's own source needs --impure on whichever real switch/build sets this field, not on mkConfigs itself).";
    };
  };
  extraSystemModulePathsOption.extraSystemModulePaths = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Absolute paths to private darwin/nixos system modules, same mechanism as extraModulePaths, for extending system/darwin.nix or system/nixos.nix. Not offered on a configs.home entry: a standalone Home Manager config has no system module layer to extend.";
  };

  # Standalone Home Manager configs: no system module layer, so no
  # extraSystemModulePaths.
  homeFeaturesType = lib.types.submodule { options = homeFeaturesOptions; };
  # darwin/nixos configs, and the call level (which legitimately spans every
  # kind, so it carries the union).
  systemFeaturesType = lib.types.submodule {
    options = homeFeaturesOptions // extraSystemModulePathsOption;
  };

  # ── Schema ─────────────────────────────────────────────────────────────
  # lib.evalModules, not a hand-rolled validator: this repo's users already
  # know this idiom from every NixOS/Home Manager module here, it is free
  # (already in nixpkgs), and with no freeformType declared anywhere, setting
  # an option that doesn't exist (today's silently-ignored `extraFeature`
  # singular typo) becomes a real "does not exist" error naming the option
  # that was meant, instead of a silent no-op.
  schemaModule =
    { lib, ... }:
    {
      options = {
        identity = lib.mkOption {
          description = "Who you are: threaded into every module as the `user` specialArg.";
          type = lib.types.submodule {
            options = {
              username = lib.mkOption {
                type = lib.types.str;
                description = "Unix username; also the Home Manager users.<username> key on darwin/nixos.";
              };
              name = lib.mkOption {
                type = lib.types.str;
                description = "Full name, used for git commit identity.";
              };
              email = lib.mkOption {
                type = lib.types.str;
                description = "Used to build the GitHub noreply commit email.";
              };
              github = lib.mkOption {
                type = lib.types.submodule {
                  options = {
                    user = lib.mkOption {
                      type = lib.types.str;
                      description = "GitHub username.";
                    };
                    id = lib.mkOption {
                      type = lib.types.nullOr lib.types.int;
                      default = null;
                      description = "GitHub numeric user id; without it, commits use the lower-privacy noreply form.";
                    };
                  };
                };
              };
            };
          };
        };

        configs = lib.mkOption {
          description = "Named configs to produce, grouped by kind so each kind's fields can't leak into another.";
          default = { };
          type = lib.types.submodule {
            options = {
              home = lib.mkOption {
                default = { };
                description = "Standalone Home Manager configs (any of the four systems, darwin included).";
                type = lib.types.attrsOf (
                  lib.types.submodule {
                    options = {
                      system = lib.mkOption { type = lib.types.enum allSystems; };
                      tier = lib.mkOption {
                        type = lib.types.enum (builtins.attrNames tiers);
                        default = "full";
                      };
                      withGui = lib.mkOption {
                        type = lib.types.bool;
                        default = false;
                      };
                      extraConfig = lib.mkOption {
                        type = lib.types.attrs;
                        default = { };
                        description = "Inline module literal merged into this config only; the generic escape hatch for anything a feature module exposes as an option (atelier.* and similar).";
                      };
                      features = lib.mkOption {
                        default = { };
                        description = "Extra/excluded features for this config only, concatenated with the call-level features option below -- not a replacement for it. A per-config exclude cannot un-exclude something the call level already excluded.";
                        type = homeFeaturesType;
                      };
                    };
                  }
                );
              };

              darwin = lib.mkOption {
                default = { };
                description = "nix-darwin + Home Manager configs. Always full tier, always GUI, matching this repo's existing darwin behavior.";
                type = lib.types.attrsOf (
                  lib.types.submodule {
                    options = {
                      system = lib.mkOption { type = lib.types.enum darwinSystems; };
                      extraConfig = lib.mkOption {
                        type = lib.types.attrs;
                        default = { };
                        description = "Inline module literal merged into this config only.";
                      };
                      features = lib.mkOption {
                        default = { };
                        description = "Extra/excluded features for this config only; see configs.home's own features option for the merge semantics.";
                        type = systemFeaturesType;
                      };
                    };
                  }
                );
              };

              nixos = lib.mkOption {
                default = { };
                description = "NixOS + Home Manager configs. Ships build-verified only in this repo; a real deployment needs a real hardwareModule.";
                type = lib.types.attrsOf (
                  lib.types.submodule {
                    options = {
                      system = lib.mkOption { type = lib.types.enum linuxSystems; };
                      hardwareModule = lib.mkOption {
                        type = lib.types.str;
                        description = "Absolute path to a real hardware-configuration.nix, as a string (imported at use time, same impure-path mechanism extraModulePaths already relies on).";
                      };
                      extraConfig = lib.mkOption {
                        type = lib.types.attrs;
                        default = { };
                        description = "Inline module literal merged into this config only.";
                      };
                      features = lib.mkOption {
                        default = { };
                        description = "Extra/excluded features for this config only; see configs.home's own features option for the merge semantics.";
                        type = systemFeaturesType;
                      };
                    };
                  }
                );
              };
            };
          };
        };

        features = lib.mkOption {
          default = { };
          description = "Which named features (modules/features.nix) get pulled in, and any additional modules beyond this repo's own, shared across every config in this call. A configs.<kind>.<name> entry's own features field adds to this rather than replacing it -- see mkConfigs' userDataFor/systemModulesFor.";
          type = systemFeaturesType;
        };
      };
    };

  # ── mkConfigs ──────────────────────────────────────────────────────────
  mkConfigs =
    args:
    let
      evaluated = lib.evalModules {
        modules = [
          schemaModule
          args
        ];
      };
      cfg = evaluated.config;

      user = mkUser cfg.identity;
      specialArgs = { inherit user; };

      # Feeds mkProfile's existing userData override point (already used by
      # the nmt harness's testUser): no feature-resolution logic duplicated
      # here, just this schema's fields mapped onto the shape mkProfile
      # already understands. Per-entry, not call-level: concatenates
      # the call-level features option with entry's own, so two configs in
      # one call can diverge (mkProfile's requestedNames/keptNames already
      # dedupe and subtract, so nothing here needs lib.unique first).
      userDataFor = entry: {
        extraFeatures = cfg.features.extra ++ entry.features.extra;
        excludeFeatures = cfg.features.exclude ++ entry.features.exclude;
        extraModulePaths = cfg.features.extraModulePaths ++ entry.features.extraModulePaths;
      };

      systemModulesFor =
        entry: map import (cfg.features.extraSystemModulePaths ++ entry.features.extraSystemModulePaths);

      mkHomeConfigFor =
        _name: entry:
        assert pairOkFor entry.system;
        (hmLibFor entry.system).homeManagerConfiguration {
          pkgs = pkgsFor entry.system;
          extraSpecialArgs = specialArgs;
          modules =
            (mkProfile {
              inherit (entry) tier;
              inherit (entry) withGui;
              inherit (entry) system;
              userData = userDataFor entry;
            })
            ++ [
              entry.extraConfig
              { nixpkgs.config = pkgsConfig; }
            ];
        };

      mkDarwinConfigFor =
        _name: entry:
        assert pairOkFor entry.system;
        (darwinLibFor entry.system).lib.darwinSystem {
          inherit (entry) system;
          inherit specialArgs;
          modules = [
            ../system/darwin.nix
          ]
          ++ systemModulesFor entry
          ++ [
            (hmDarwinModuleFor entry.system)
            {
              nixpkgs.pkgs = pkgsFor entry.system;
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = false;
                backupFileExtension = "bk";
                extraSpecialArgs = specialArgs;
                users.${user.username}.imports =
                  (mkProfile {
                    inherit (entry) system;
                    tier = "full";
                    withGui = true;
                    userData = userDataFor entry;
                  })
                  ++ [ entry.extraConfig ];
              };
            }
          ];
        };

      mkNixosConfigFor =
        _name: entry:
        lib.nixosSystem {
          inherit (entry) system;
          inherit specialArgs;
          modules = [
            ../system/nixos.nix
            (import entry.hardwareModule)
          ]
          ++ systemModulesFor entry
          ++ [
            nixosHmModule
            {
              # useGlobalPkgs means Home Manager uses NixOS's own pkgs, not a
              # separately-instantiated one -- so that pkgs needs the same
              # rust-overlay pkgsFor already applies for home/darwin, set
              # here the NixOS way (nixpkgs.pkgs), or featureMods that expect
              # rust-bin (lang-rust.nix) fail with "undefined variable"
              # inside home-manager.users.<username>.packages. Found by an
              # actual build, not eval alone: eval-only checks never force
              # this option.
              nixpkgs.pkgs = pkgsFor entry.system;
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = specialArgs;
                users.${user.username}.imports =
                  (mkProfile {
                    inherit (entry) system;
                    tier = "full";
                    withGui = true;
                    userData = userDataFor entry;
                  })
                  ++ [ entry.extraConfig ];
              };
            }
          ];
        };
    in
    {
      homeConfigurations = lib.mapAttrs mkHomeConfigFor cfg.configs.home;
      darwinConfigurations = lib.mapAttrs mkDarwinConfigFor cfg.configs.darwin;
      nixosConfigurations = lib.mapAttrs mkNixosConfigFor cfg.configs.nixos;
    };
in
{
  inherit mkConfigs mkUser;

  # Both re-exported alongside mkConfigs: flake.nix's own matrix generation
  # (tier x gui x arch for its dogfooded configs) and the nmt harness both
  # need the compositor and the tier registry directly, not just the
  # finished mkConfigs entry point. One import (this file) is now the whole
  # surface; neither has to reach into lib/mkProfile.nix separately.
  inherit (mkProfileLib) mkProfile tiers;

  # Schema validation only, no kind-building: exposed for flake.nix's own
  # checks to prove a misspelled or cross-kind field is rejected, via
  # builtins.deepSeq forcing the whole config tree. Not part of the public
  # lib.mkConfigs surface (flake.nix's own outputs.lib exports mkConfigs
  # alone), same as mkNmtModules staying internal to the nmt harness.
  evalConfig =
    args:
    (lib.evalModules {
      modules = [
        schemaModule
        args
      ];
    }).config;
}
