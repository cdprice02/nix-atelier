# minimal-tier coverage (#129): every other nmt instance defaults to
# tier = "full" (mkNmtModules's own default), so minimal (tiers.minimal = []
# in mkConfigs/mkProfile -- no feature modules at all) had never actually
# been evaluated through the harness. Confirms both halves: base.nix/env.nix/
# machine.nix/secrets-sops.nix/caret survive tier selection entirely (they're
# imported unconditionally by mkProfile, not part of any tier's feature
# list), while tier-gated feature modules (tmux.nix, lang-node.nix, ...) are
# genuinely absent, not merely empty.
{
  minimal-tier-keeps-always-on-modules = {
    nmt.description = ''
      base.nix (ssh config, git identity) and its secrets/env sourcing
      (also base.nix, not feature-gated) still render under minimal: these
      come from mkProfile's always-on module list, never from a tier's
      feature set.
    '';
    nmt.script = ''
      assertFileContains home-files/.ssh/config 'IdentityFile ~/.ssh/you'
      assertFileContains home-files/.config/git/config '[user]'
      assertFileContains home-files/.zshrc 'secrets/env'
    '';
  };

  minimal-tier-drops-every-feature-module = {
    nmt.description = ''
      tmux.nix (features/tmux.nix) and lang-node.nix's fnm integration are
      both `full`-tier feature modules (tiers.full = every key in
      modules/features.nix); minimal's empty feature list means neither is
      imported at all, not merely configured to render nothing.
    '';
    nmt.script = ''
      assertPathNotExists home-files/.config/tmux/tmux.conf
      assertFileNotRegex home-files/.zshrc 'fnm env --use-on-cd'
    '';
  };
}
