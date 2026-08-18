# Generated ~/.ssh/config content (#129). The most fragile compatibility
# shim in the repo sits behind this file: hm-compat.nix's sshBlocks converts
# this repo's own upstream-directive-named blocks into whichever shape the
# evaluating home-manager pin wants (typed matchBlocks on 25.05, freeform
# settings on master), with a hand-maintained directive table and a
# throw-on-unmapped fallback -- but the two shapes render to the identical
# final ssh_config(5) text either way, which is what actually matters and
# what this asserts on, rather than which internal option path produced it.
#
# UseKeychain is darwin-only (base.nix gates it on pkgs.stdenv.isDarwin), so
# `system` decides which assertions apply, the same pattern symlinks.nix
# uses for its own darwin-conditional expected path.
{ system }:
let
  isDarwin = builtins.match ".*-darwin" system != null;
in
{
  ssh-config-renders-identity-and-github-blocks = {
    nmt.description = ''
      base.nix's programs.ssh: the unmanaged-stub include, the wildcard
      block's IdentityFile/AddKeysToAgent (keyed off user.sshKey, "you" for
      the harness's placeholder identity), and github.com's User/IdentitiesOnly
      -- plus UseKeychain on darwin only, the one line hm-compat.nix's
      sshBlocks has to plumb through despite not being a directive-name
      rename at all.
    '';
    nmt.script = ''
      assertFileContains home-files/.ssh/config 'Include ~/.ssh/config.d/*'
      assertFileContains home-files/.ssh/config 'IdentityFile ~/.ssh/you'
      assertFileContains home-files/.ssh/config 'AddKeysToAgent yes'
      assertFileContains home-files/.ssh/config 'Host github.com'
      assertFileContains home-files/.ssh/config 'User git'
      assertFileContains home-files/.ssh/config 'IdentitiesOnly yes'
    ''
    + (
      if isDarwin then
        ''
          assertFileContains home-files/.ssh/config 'UseKeychain yes'
        ''
      else
        ''
          assertFileNotRegex home-files/.ssh/config '^\s*UseKeychain'
        ''
    );
  };
}
