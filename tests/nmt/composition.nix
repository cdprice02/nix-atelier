# Composition variant (issue #53): runs against an nmt instance built with
# userDataOverrides = { excludeFeatures = ["tmux"]; extraModulePaths =
# [fixtures/private-identity.nix]; } (flake.nix's nmt-composition-* checks),
# proving the two escape hatches actually work rather than just evaluating
# without error. Combined into one instance instead of two separate ones:
# a real machine plausibly uses both at once (a private module plus an
# exclusion), and there's no interaction between them worth isolating.
{
  exclude-features-drops-tmux = {
    nmt.description = ''
      excludeFeatures = ["tmux"] should remove tmux.conf entirely, not just
      leave it unconfigured -- mkProfile subtracts the name from the
      requested feature list before resolving modules, so the module (and
      everything it owns) should never be imported at all.
    '';
    nmt.script = ''
      assertPathNotExists home-files/.config/tmux/tmux.conf
    '';
  };

  extra-module-path-overrides-git-identity = {
    nmt.description = ''
      extraModulePaths layers a private module on top of the profile;
      fixtures/private-identity.nix mirrors examples/private-config's own
      identity-override shape (hm-compat's gitIdentity with force = true) to
      prove the mechanism a real private module actually relies on: base.nix
      sets the personal identity at a real priority (not mkDefault), so an
      override without force would conflict rather than win.
    '';
    nmt.script = ''
      assertFileContains home-files/.config/git/config 'name = "Fixture Override"'
      assertFileContains home-files/.config/git/config 'email = "fixture-override@example.com"'
    '';
  };
}
