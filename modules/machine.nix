# Framework-level, always-on (like base.nix/env.nix): machine-specific
# integration that isn't tied to any one feature (#120). Previously
# nativeInstallers/configRepos lived entirely inside claude.nix, the first
# and only consumer, which meant excludeFeatures = ["claude"] silently
# disabled both mechanisms for anyone using them for something unrelated to
# Claude. atelier.aws.profile and atelier.sops.* move here too, for the same
# reason: they're machine-level settings, not feature-gated ones (cloud.nix
# and secrets-sops.nix only consume them, they don't own them).
#
# mkConfigs (#122) callers set these through a config's own extraConfig; this
# repo's own placeholder identity sets them (all defaults) through the
# bridge module in flake.nix's mkProfile (translating userData's flat
# aws/nativeInstallers/configRepos/sops fields into these options via
# lib.mkDefault, so a real extraConfig definition elsewhere always wins
# without conflicting).
{
  config,
  lib,
  pkgs,
  user,
  ...
}:
let
  mkNativeInstaller = import ./lib/native-installer.nix { inherit pkgs user; };

  # Keyed by binary name so two entries can't collide silently.
  nativeInstallerMods = lib.listToAttrs (
    map (spec: {
      name = "nativeInstaller-${spec.binary}";
      value = lib.hm.dag.entryAfter [ "writeBoundary" ] (mkNativeInstaller {
        inherit (spec) binary url;
      });
    }) config.atelier.nativeInstallers
  );

  # Real, independently-pushed git clones of private config repos, keyed by
  # the path under $HOME to clone into. Not submodules of this (public) repo:
  # a private submodule would break every CI job's `submodules: recursive`
  # checkout (no credentials for a private repo there), and the URL would
  # otherwise have to live in this public repo's .gitmodules. Guarded like
  # the SSH-key activation hook in base.nix: write-once, never re-clones over
  # local changes.
  configRepoMods = lib.mapAttrs' (
    path: url:
    lib.nameValuePair "configRepo-${path}" (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ ! -d "$HOME/${path}/.git" ]; then
          $DRY_RUN_CMD ${pkgs.git}/bin/git clone "${url}" "$HOME/${path}"
        fi
      ''
    )
  ) config.atelier.configRepos;
in
{
  options.atelier = {
    aws.profile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Default AWS_PROFILE for this machine. Left unset by default: a hardcoded default risks a command silently hitting the wrong account.";
    };

    nativeInstallers = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            binary = lib.mkOption { type = lib.types.str; };
            url = lib.mkOption { type = lib.types.str; };
          };
        }
      );
      default = [ ];
      description = "Extra native-installer CLIs (vendor curl-piped install scripts), for tools that aren't in nixpkgs or update too fast for Nix's rebuild cycle to track. The framework has no opinion on what these are.";
    };

    configRepos = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Private config repos to clone, keyed by the path under $HOME to clone into.";
    };

    sops = {
      file = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Absolute path to a real secrets.yaml. Presence is the on/off switch for sops-nix; unset means the manual ~/.config/secrets/env path, which stays fully supported.";
      };
      secrets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Secret names to decrypt from atelier.sops.file. Only meaningful when file is set.";
      };
    };

    submodules = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Private remote overrides for config/ submodules, keyed by submodule name. See base.nix's submoduleOverrides activation script.";
    };
  };

  config = {
    home.activation = nativeInstallerMods // configRepoMods;
  };
}
