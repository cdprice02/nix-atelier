# The pure, consumable entry point (#122). A plain function of a typed
# argument attrset to { homeConfigurations; darwinConfigurations;
# nixosConfigurations; }, no getEnv, no --impure.
#
# Three dependencies, each a genuinely distinct concern: `lib` (the standard
# library), `systems` (lib/systems.nix -- which of the two release pairs a
# system uses, and the resolved pkgs/home-manager/nix-darwin for it), and
# `mkProfile` (this repo's existing feature compositor, unchanged). Identity
# handling (mkUser) and the tier registry are self-contained here rather than
# threaded in: neither has any real dependency on flake.nix beyond a source
# file this module is exactly as close to.
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
  mkProfile,
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
    ;

  # Derive SSH key name from email prefix: key file ~/.ssh/<sshKey>. Shared
  # with the nmt harness's testUser, so both go through the same derivation;
  # flake.nix's still-impure user.nix path imports this back out (see the
  # attrset returned at the bottom of this file) rather than keeping its own
  # copy.
  mkUser = base: base // { sshKey = builtins.elemAt (builtins.split "@" base.email) 0; };

  # Same registry mkProfile itself resolves feature names against: tier
  # *names* are all this schema needs (to validate `tier`), not the feature
  # modules themselves, which mkProfile already owns.
  tiers = {
    minimal = [ ];
    full = builtins.attrNames (import ../modules/features.nix);
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
                    };
                  }
                );
              };

              nixos = lib.mkOption {
                default = { };
                description = "NixOS + Home Manager configs (#5). Ships build-verified only in this repo; a real deployment needs a real hardwareModule.";
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
                    };
                  }
                );
              };
            };
          };
        };

        features = lib.mkOption {
          default = { };
          description = "Which named features (modules/features.nix) get pulled in, and any additional modules beyond this repo's own.";
          type = lib.types.submodule {
            options = {
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
                description = "Absolute paths to private Home Manager modules, as strings (imported at use time; requires --impure only for the caller's own use of getEnv, not for this function).";
              };
              extraSystemModulePaths = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Absolute paths to private darwin/nixos system modules, same mechanism as extraModulePaths, for extending system/darwin.nix or system/nixos.nix.";
              };
            };
          };
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
      # already understands.
      userData = {
        extraFeatures = cfg.features.extra;
        excludeFeatures = cfg.features.exclude;
        inherit (cfg.features) extraModulePaths;
      };

      systemModules = map import cfg.features.extraSystemModulePaths;

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
              inherit userData;
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
          ++ systemModules
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
                    inherit userData;
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
          ++ systemModules
          ++ [
            nixosHmModule
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = specialArgs;
                users.${user.username}.imports =
                  (mkProfile {
                    inherit (entry) system;
                    tier = "full";
                    withGui = true;
                    inherit userData;
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
