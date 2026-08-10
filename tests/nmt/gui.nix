# Positive half of the GUI/headless pair (issue #53): runs against a
# withGui = true nmt instance (flake.nix's nmt-gui-* checks), which
# mkProfile resolves to gui-darwin.nix on a darwin system and gui-linux.nix
# otherwise. Paired with gui-absent.nix's negative assertion in the default
# instance -- see that file's own comment for why the pair matters together.
{
  system,
  lib,
}: let
  isDarwin = builtins.match ".*-darwin" system != null;
  keybindingsAssertions = [
    "chars = \"\\u0001\""
    "chars = \"\\u0005\""
    "chars = \"\\u0015\""
    "chars = \"\\u001bb\""
    "chars = \"\\u001bf\""
  ];
in
  {
    gui-has-alacritty = {
      nmt.description = ''
        Both gui-linux.nix and gui-darwin.nix own programs.alacritty; confirm
        the rendered config actually exists on a GUI build, the positive
        counterpart to gui-absent.nix's headless assertion.
      '';
      nmt.script = ''
        assertFileExists home-files/.config/alacritty/alacritty.toml
      '';
    };
  }
  // lib.optionalAttrs isDarwin {
    darwin-gui-keybindings-use-toml-unicode-escapes = {
      nmt.description = ''
        gui-darwin.nix encodes Cmd/Option+arrow keybindings as TOML \uXXXX
        escapes because the literal control bytes they represent (Ctrl-A,
        Ctrl-E, Ctrl-U, ESC b, ESC f) are invalid TOML -- a mangling a build
        would happily accept, since Nix's own string handling doesn't care
        either way. Pinning the literal escape text catches that specific
        class of regression, which only shows up when alacritty itself
        tries to parse the file. Linux never carries this file at all
        (gui-linux.nix's own alacritty config has no keybindings.toml), so
        this half is darwin-only.
      '';
      nmt.script =
        lib.concatMapStringsSep "\n"
        (line: "assertFileContains home-files/.config/alacritty/keybindings.toml '${line}'")
        keybindingsAssertions;
    };
  }
