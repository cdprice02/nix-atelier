# nmt test registry: name -> module fragment (nmt.description / nmt.script),
# evaluated against the module list flake.nix's mkNmtTests builds. One file
# per area, folded together the same way home-manager's own tests/default.nix
# folds its per-module test directories -- add a new area by adding a key
# here, not by editing the harness in flake.nix.
#
# `system` is threaded through to any file whose assertions depend on it
# (e.g. symlinks.nix's expected home directory, which differs between darwin
# and Linux) -- files that don't need it just ignore the argument, matching
# shell-init.nix/dotfile-content.nix's plain-attrset shape below.
{ system }:
{
  activation-package-renders = {
    nmt.description = ''
      Sanity check for the harness itself: the activation package evaluates
      to a real home-files tree without building any actual package (every
      derivation referenced along the way is scrubbed to a "@name@"
      placeholder by flake.nix's mkNmtModules). If this fails, something
      about the harness wiring is broken, not the config it is testing.
    '';
    nmt.script = ''
      assertDirectoryExists home-files
      assertFileExists home-files/.zshrc
    '';
  };
}
// import ./shell-init.nix
// import ./dotfile-content.nix
// import ./symlinks.nix { inherit system; }
// import ./tmux.nix
// import ./gui-absent.nix
// import ./activation.nix
// import ./ssh-config.nix { inherit system; }
