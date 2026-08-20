# Fixture for machine-integration.nix's nmt instance: sets non-default
# values for every atelier.* option machine.nix/base.nix own, so their
# activation scripts (empty/absent under the harness's default fixture,
# since these are user-declared and default to empty) actually render
# something to assert on. Lives inside the repo's own tree for the same
# reason tests/nmt/fixtures/private-identity.nix does: a fixture has to be
# something the harness can resolve deterministically.
{
  atelier = {
    nativeInstallers = [
      {
        binary = "examplebin";
        url = "https://example.com/install.sh";
      }
      # A second entry alongside examplebin, specifically to exercise
      # machine.nix's kiro-cli shellAliases guard: examplebin proves the
      # generic mechanism works for an arbitrary binary, kiro-cli proves the
      # alias is keyed on binary name and not on nativeInstallers being
      # non-empty at all (see kiro-cli-alias-only-when-declared below).
      {
        binary = "kiro-cli";
        url = "https://example.com/kiro-install.sh";
      }
    ];
    configRepos = {
      "repos/private-notes" = "git@example.com:you/private-notes.git";
    };
    submodules = {
      claude = "git@example.com:you/private-claude.git";
    };
  };
}
