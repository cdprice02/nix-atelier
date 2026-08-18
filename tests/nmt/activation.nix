# Activation script coverage (#129): base.nix's sshKey hook, and the
# mkNativeInstaller/awsConfigSkeleton hooks already exercised by the default
# full/headless fixture (claude.nix's claudeCode entry, cloud.nix's
# awsConfigSkeleton -- cloud is part of the full tier, so both are already
# present with no extra fixture needed). The generic atelier.nativeInstallers/
# configRepos/submodules mechanisms (machine.nix, base.nix) are user-declared
# and empty by default, so they get their own fixture and nmt instance in
# machine-integration.nix instead of living here.
#
# These are the only unsandboxed shell code in the repo that runs during a
# real switch (nmt renders the same `activate` script a real switch would
# run, just never executes it) -- previously asserted on nowhere but
# bootstrap-smoke-test's incidental, non-assertive exercise of them.
{
  sshkey-activation-script-generates-key-with-correct-comment = {
    nmt.description = ''
      base.nix's sshKey hook: guarded on the key not already existing,
      ed25519, commented with the user's email, and named after
      user.sshKey (derived from the email prefix -- "you" for the harness's
      placeholder "you@example.com").
    '';
    nmt.script = ''
      assertFileContains activate 'if [ ! -f "$HOME/.ssh/you" ]; then'
      assertFileContains activate 'ssh-keygen -t ed25519 -C "you@example.com"'
      # Leading space, not a bare "-f...": grep would otherwise parse a
      # pattern starting with "-f" as its own "read patterns from file" flag.
      assertFileContains activate ' -f "$HOME/.ssh/you" -N ""'
      assertFileContains activate 'SSH key generated: ~/.ssh/you'
    '';
  };

  native-installer-renders-both-root-and-non-root-branches = {
    nmt.description = ''
      mkNativeInstaller's `sudo -u` root-elevation branch (darwin-rebuild
      switch runs as root; the installer must delegate to the target user
      so it never creates root-owned files in $HOME) has never been
      asserted on. Both branches are static bash text in the rendered
      script regardless of which one a real switch takes at runtime, so
      both are checkable here without actually running as root. Exercised
      via claude.nix's claudeCode entry, the same mkNativeInstaller call
      atelier.nativeInstallers (machine-integration.nix) also goes through.
    '';
    nmt.script = ''
      assertFileContains activate 'if [ "$(id -u)" -eq 0 ]; then'
      assertFileContains activate '/usr/bin/sudo -u yourusername \'
      assertFileContains activate 'env HOME="$HOME" PATH='
      assertFileContains activate 'else'
      assertFileContains activate 'env PATH='
      assertFileContains activate "|| echo \"WARNING: claude install failed; rerun 'just switch' to retry.\""
    '';
  };

  aws-config-skeleton-written-once = {
    nmt.description = ''
      cloud.nix's awsConfigSkeleton: guarded on the file not already
      existing (so a real switch never clobbers profiles the user has since
      added by hand), and the DRY_RUN_CMD branch that skips the write
      entirely under a dry run rather than truncating the real file with a
      literal "cat" (the bug this branch specifically exists to avoid).
    '';
    nmt.script = ''
      assertFileContains activate 'if [ ! -f "$HOME/.aws/config" ]; then'
      assertFileContains activate 'if [ -n "''${DRY_RUN_CMD:-}" ]; then'
      assertFileContains activate 'echo "Would create $HOME/.aws/config"'
      assertFileContains activate '[default]'
      assertFileContains activate '~/.aws/config created: edit to add named profiles.'
    '';
  };
}
