{
  config,
  pkgs,
  user,
  lib,
  ...
}:
let
  mkNativeInstaller = import ../lib/native-installer.nix { inherit pkgs user; };
in
{
  # Submodule under config/ symlinked into HOME so tools find it at the
  # expected path. mkOutOfStoreSymlink keeps it live-editable (not copied
  # into the Nix store), which is required for a git-managed tool config.
  home.file.".claude" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.atelier.checkoutPath}/config/claude";
  };

  home.activation = {
    # claude-code via its own native installer, not npm or nixpkgs: it ships
    # multiple releases a week and self-updates in place (`claude update`);
    # Nix's rebuild-to-update cycle can't keep pace, and nixpkgs's packaged
    # version lags too. Installs to ~/.local/bin/claude, already on PATH via
    # env.nix's XDG_BIN_HOME. Unlike machine.nix's atelier.nativeInstallers
    # (#120), this one is not user-declared: every machine with this feature
    # gets Claude Code, the same way any other feature's packages aren't
    # opt-in per-item.
    #
    # entryAfter ["linkGeneration"], not "writeBoundary": on a genuinely
    # fresh machine (no prior ~/.local/bin/claude), the installer's own
    # first-run setup creates ~/.claude as a real directory for its default
    # config. home.file.".claude" above wants that same path as its
    # symlink target, but linkGeneration (home-manager's own built-in phase
    # that materializes home.file) only runs after every custom
    # writeBoundary-anchored activation script -- so at "writeBoundary"
    # priority the installer would always win the race and leave `ln`
    # nothing to do but fail with "cannot overwrite directory". Anchoring
    # after linkGeneration instead means the symlink exists first, so the
    # installer just writes its defaults straight into the already-live
    # config/claude submodule, matching this repo's actual steady-state
    # (Claude Code's runtime state living inside a git-tracked submodule).
    # Found by bootstrap-smoke-test's own fresh-container run, not assumed.
    claudeCode = lib.hm.dag.entryAfter [ "linkGeneration" ] (mkNativeInstaller {
      binary = "claude";
      url = "https://claude.ai/install.sh";
    });
  };
}
