# nmt test registry: name -> module fragment (nmt.description / nmt.script),
# evaluated against the module list flake.nix's mkNmtTests builds. One file
# per area, folded together the same way home-manager's own tests/default.nix
# folds its per-module test directories -- add a new area by adding a key
# here, not by editing the harness in flake.nix.
_: {
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
