# Coverage (#129) for the user-declared atelier.* activation mechanisms
# (machine.nix, base.nix): nativeInstallers, configRepos, submodules. All
# three render nothing under the harness's default fixture (empty by
# default -- user-declared, not framework defaults), so this runs against
# its own nmt instance layering in fixtures/machine-integration.nix via
# extraModulePaths, the same real mechanism a private machine module uses.
#
# `system` is needed for the submodule-override assertion below: atelier.
# checkoutPath (#149) defaults to a Nix-computed homeDirectory, which
# differs between darwin and Linux, same reason symlinks.nix takes it.
{ system }:
let
  isDarwin = builtins.match ".*-darwin" system != null;
  homeDir = if isDarwin then "/Users/yourusername" else "/home/yourusername";
in
{
  generic-native-installer-renders-for-declared-binary = {
    nmt.description = ''
      atelier.nativeInstallers (machine.nix) goes through the same
      mkNativeInstaller as claude.nix's hardcoded claudeCode entry, keyed
      by binary name instead. Confirms a user-declared entry actually
      renders, not just the one entry the framework ships itself.
    '';
    nmt.script = ''
      assertFileContains activate 'Activating %s" "nativeInstaller-examplebin"'
      assertFileContains activate 'if [ -z "$DRY_RUN_CMD" ] && [ ! -x "$HOME/.local/bin/examplebin" ]; then'
      assertFileContains activate 'installing examplebin via its native installer'
      assertFileContains activate 'curl -fsSL https://example.com/install.sh'
      assertFileContains activate 'WARNING: examplebin install failed; rerun'
    '';
  };

  config-repo-clone-guarded-on-existing-checkout = {
    nmt.description = ''
      atelier.configRepos (machine.nix): a private repo clone, keyed by the
      path under $HOME to clone into, guarded so a real switch never
      re-clones over local changes.
    '';
    nmt.script = ''
      assertFileContains activate 'Activating %s" "configRepo-repos/private-notes"'
      assertFileContains activate 'if [ ! -d "$HOME/repos/private-notes/.git" ]; then'
      assertFileContains activate 'clone "git@example.com:you/private-notes.git" "$HOME/repos/private-notes"'
    '';
  };

  kiro-cli-alias-only-when-declared = {
    nmt.description = ''
      machine.nix guards programs.{zsh,bash}.shellAliases.kiro-cli on
      atelier.nativeInstallers actually containing a kiro-cli entry (the
      fixture declares one alongside examplebin above), not on
      nativeInstallers being non-empty at all -- so a config that installs
      some other native binary doesn't get a dangling alias for a kiro-cli
      that was never installed. See shell-init.nix's
      no-kiro-cli-alias-without-nativeinstaller for the negative case, under
      the default fixture where no kiro-cli entry exists at all.
    '';
    nmt.script = ''
      assertFileRegex home-files/.zshrc 'kiro-cli=.*kiro-cli --v3'
      assertFileRegex home-files/.bashrc 'kiro-cli=.*kiro-cli --v3'
    '';
  };

  submodule-override-wires-private-remote = {
    nmt.description = ''
      atelier.submodules (base.nix): adds a private remote to the named
      config/ submodule and tracks its work branch, idempotent (skips if
      the private remote already exists). Empty by default under the
      harness's baseline fixture (see the submoduleOverrides marker in
      activation.nix, present but content-free there); this asserts the
      real per-name script once one is actually declared.
    '';
    nmt.script = ''
      assertFileContains activate '_sm_dir="${homeDir}/.nix-atelier/config/claude"'
      assertFileContains activate 'remote add private "git@example.com:you/private-claude.git"'
      assertFileContains activate 'checkout -b work --track private/main'
    '';
  };
}
