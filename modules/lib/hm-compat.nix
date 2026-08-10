# Option-name shims for the two home-manager versions this repo pins.
#
# Per flake.nix's input-pairing invariant, Linux/WSL2 and aarch64-darwin ride
# home-manager master while x86_64-darwin is pinned to release-25.05. Master has
# since renamed several options that this config sets; 25.05 predates every one
# of those renames and has no alias for the new spellings. Picking either
# spelling outright breaks the other pair, and the old spellings emit a
# deprecation warning on every eval and switch of a rolling profile.
#
# Each helper below emits whichever spelling the *evaluating* home-manager
# actually has, so one module source stays valid on both. This is the same idiom
# as the pre-existing `options.programs.ssh ? enableDefaultConfig` guard,
# extracted so it isn't re-derived in five separate files.
#
# Callers pass their own module arguments:
#   compat = import ../lib/hm-compat.nix {inherit lib options pkgs;};
#
# Delete a helper once the pinned darwin input moves past the rename that
# motivated it: at that point both pairs agree and the shim is dead weight.
{
  lib,
  options,
  ...
}: rec {
  # ── Capability probes ───────────────────────────────────────────────────────
  # Probed off `options`, not a version string: an option either exists in the
  # evaluating module tree or it doesn't, which is the thing actually being
  # branched on.
  hasGitSettings = options.programs.git ? settings;
  hasDeltaModule = options.programs ? delta;
  hasSshSettings = options.programs.ssh ? settings;

  # ── git ─────────────────────────────────────────────────────────────────────
  # master: programs.git.extraConfig -> programs.git.settings
  # Both take the same gitIniType attrset, so only the attribute name moves.
  # Returns a fragment to merge into `programs.git`, letting several modules
  # each contribute their own slice (base + git-tools + gui-*) exactly as they
  # did with extraConfig.
  gitConfig = cfg:
    if hasGitSettings
    then {settings = cfg;}
    else {extraConfig = cfg;};

  # master: programs.git.userName/userEmail -> programs.git.settings.user.name/.email
  # `force` covers work.nix, which overrides base.nix's personal identity and
  # therefore needs mkForce on whichever spelling is live.
  gitIdentity = {
    name,
    email,
    force ? false,
  }: let
    wrap =
      if force
      then lib.mkForce
      else lib.id;
  in
    if hasGitSettings
    then {
      settings.user = {
        name = wrap name;
        email = wrap email;
      };
    }
    else {
      userName = wrap name;
      userEmail = wrap email;
    };

  # ── delta ───────────────────────────────────────────────────────────────────
  # master: programs.git.delta.{enable,options} -> programs.delta.{enable,options},
  # with git wiring split out into programs.delta.enableGitIntegration (which
  # master auto-enables at a low priority and warns about, so it is set
  # explicitly). 25.05 has no programs.delta module at all.
  # Returns a fragment to merge into `programs`.
  deltaConfig = deltaOptions:
    if hasDeltaModule
    then {
      delta = {
        enable = true;
        enableGitIntegration = true;
        options = deltaOptions;
      };
    }
    else {
      git.delta = {
        enable = true;
        options = deltaOptions;
      };
    };

  # ── ssh ─────────────────────────────────────────────────────────────────────
  # master: programs.ssh.matchBlocks -> programs.ssh.settings. Not a plain
  # rename: the shape changes too. matchBlocks took typed camelCase options
  # (identityFile, identitiesOnly) plus a freeform `extraOptions` escape hatch;
  # settings is freeform throughout and keyed by upstream ssh_config(5)
  # directive names (IdentityFile, IdentitiesOnly), with extraOptions explicitly
  # unsupported. Booleans render as yes/no in both.
  #
  # Callers therefore pass the upstream-directive form, and this converts back
  # to the legacy shape for 25.05. Only the directives this repo actually uses
  # are mapped; an unmapped one would silently vanish on the pinned pair, so the
  # fallback throws instead.
  sshBlocks = blocks:
    if hasSshSettings
    then {settings = blocks;}
    else let
      legacyNames = {
        IdentityFile = "identityFile";
        User = "user";
        IdentitiesOnly = "identitiesOnly";
        HostName = "hostname";
        Port = "port";
      };
      # Directives with no typed 25.05 equivalent ride extraOptions, which is
      # exactly what that escape hatch existed for.
      toLegacy = name: block: let
        typed =
          lib.mapAttrs' (
            directive: value:
              lib.nameValuePair legacyNames.${directive} value
          )
          (lib.filterAttrs (d: _: legacyNames ? ${d}) block);
        extra = lib.filterAttrs (d: _: !(legacyNames ? ${d})) block;
      in
        lib.throwIf (block ? header)
        "hm-compat.sshBlocks: `header` has no programs.ssh.matchBlocks equivalent (block ${name})"
        (typed // lib.optionalAttrs (extra != {}) {extraOptions = extra;});
    in {
      matchBlocks = lib.mapAttrs toLegacy blocks;
    };

  # master injects a default `*` match block and warns unless this is off; 25.05
  # has neither the option nor the injection. Kept so the explicit `*` block
  # stays authoritative on both.
  sshDefaultConfigOff =
    lib.optionalAttrs (options.programs.ssh ? enableDefaultConfig)
    {enableDefaultConfig = false;};
}
