# The profile compositor (#122), extracted from flake.nix (#143): produces
# the ordered module list for a config. Owns the tier registry too
# (features.nix -> tiers), the one place it's computed -- lib/mkConfigs.nix
# imports both mkProfile and tiers from here instead of each keeping its own
# copy of the tier derivation.
#
# isLinux/sopsNixModule/caretModule are dependencies, not owned here: isLinux
# is lib/systems.nix's concern (which systems count as Linux), and the sops-
# nix/caret modules are flake inputs' own outputs, threaded in by whichever
# caller actually has them (flake.nix, via lib/mkConfigs.nix).
{
  lib,
  isLinux,
  sopsNixModule,
  caretModule,
}:
let
  # features.nix: name -> module path registry. core/env aren't in it:
  # they're an always-on prefix mkProfile adds unconditionally, not a
  # selectable feature. tiers is derived from that same registry, so a new
  # feature joins `full` automatically and there is no second list to keep
  # in sync.
  features = import ../modules/features.nix;
  tiers = {
    minimal = [ ];
    full = builtins.attrNames features;
  };

  # A features.nix entry is either a bare path or an attrset
  # { module; unsupported; } (see that file's own comment). These two
  # accessors are the only place that shape distinction is unwrapped.
  featureModule = f: if builtins.isAttrs f then f.module else f;
  featureUnsupported = f: if builtins.isAttrs f then (f.unsupported or [ ]) else [ ];
in
{
  inherit tiers;

  # tier    : "minimal" | "full"
  # withGui : bool: gui module auto-selected from system
  # featuresOverride defaults to the real top-level `features` registry, so
  # every real call site (mkConfigs' three kind-builders, the nmt harness) is
  # unaffected; the platform-filtering check exercises a synthetic
  # unsupported feature by overriding it, without adding test-only noise to
  # the real, shipped registry. userData has no default: every real and test
  # call site already passes it explicitly, and a default here would need to
  # close over an identity this file has no business owning.
  mkProfile =
    {
      tier,
      withGui,
      system,
      userData,
      featuresOverride ? features,
    }:
    let
      resolveFeature =
        name:
        featuresOverride.${name} or (throw ''
          unknown feature "${name}": valid features: ${builtins.concatStringsSep ", " (builtins.attrNames featuresOverride)}
        '');
      # Tier defaults plus the caller's extraFeatures (features.extra in a
      # mkConfigs call), deduplicated (a name in both is not an error: the
      # module system already dedupes imports by file, so this has always
      # been silently fine -- unique here just avoids resolving the same
      # name twice). excludeFeatures (features.exclude) is the inverse
      # escape hatch: names to drop regardless of where they came from,
      # and also how a machine silences the unsupported-platform warning
      # below for a feature it was never going to use anyway.
      requestedNames = lib.unique (
        (tiers.${tier} or (throw "unknown tier \"${tier}\"")) ++ (userData.extraFeatures or [ ])
      );
      keptNames = lib.subtractLists (userData.excludeFeatures or [ ]) requestedNames;

      supportedOn = name: !(builtins.elem system (featureUnsupported (resolveFeature name)));
      usableNames = builtins.filter supportedOn keptNames;
      skippedNames = builtins.filter (n: !(supportedOn n)) keptNames;

      featureMods = map (n: featureModule (resolveFeature n)) usableNames;

      # Absolute paths to private, machine-specific modules outside this
      # repo: a string absolute path imports to a real module, and relative
      # imports inside it resolve against the real filesystem. Resolving an
      # absolute path outside the flake's own source needs --impure on
      # whichever real switch/build actually sets this field; the schema
      # itself (mkConfigs's features.extraModulePaths) doesn't require it.
      # See examples/private-config/ for a worked example. Empty by default.
      privateMods = map import (userData.extraModulePaths or [ ]);

      guiMods =
        if !withGui then
          [ ]
        else if isLinux system then
          [ ../modules/gui-linux.nix ]
        else
          [ ../modules/gui-darwin.nix ];

      # Bridges userData's flat aws/nativeInstallers/configRepos/sopsFile/
      # secrets fields onto machine.nix's atelier.* options (#120): used
      # by this repo's own placeholder identity below (all defaults) and
      # by the nmt harness's testUser. lib.mkDefault, not a plain
      # assignment: a mkConfigs (#122) caller's own extraConfig setting
      # the same option is a real, higher-priority definition and must
      # win outright rather than conflicting with this fallback.
      machineBridge = {
        atelier = {
          aws.profile = lib.mkDefault (userData.aws.profile or null);
          nativeInstallers = lib.mkDefault (userData.nativeInstallers or [ ]);
          configRepos = lib.mkDefault (userData.configRepos or { });
          sops = {
            file = lib.mkDefault (userData.sopsFile or null);
            secrets = lib.mkDefault (userData.secrets or [ ]);
          };
          submodules = lib.mkDefault (userData.submodules or { });
        };
      };
    in
    lib.warnIf (skippedNames != [ ])
      ''
        Skipping features unsupported on ${system}: ${lib.concatStringsSep ", " skippedNames}.
        Add them to features.exclude in your mkConfigs call to silence this.
      ''
      (
        [
          ../modules/base.nix
          ../modules/env.nix
          ../modules/machine.nix
          sopsNixModule
          ../modules/secrets-sops.nix
          caretModule
          machineBridge
        ]
        ++ featureMods
        ++ privateMods
        ++ guiMods
      );
}
