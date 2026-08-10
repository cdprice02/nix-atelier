# Negative half of the GUI/headless pair (issue #53): the harness's default
# instance is withGui = false, so this runs for free against the existing
# baseline fixture. The positive half (alacritty present on a GUI build) is
# in gui.nix, which needs its own withGui = true nmt instance -- see
# flake.nix's nmt-gui-* checks.
{
  headless-has-no-alacritty = {
    nmt.description = ''
      gui-linux.nix/gui-darwin.nix both own programs.alacritty; a headless
      profile never imports either, so alacritty.toml (and darwin's
      keybindings.toml) shouldn't exist. Only meaningful pinned as a pair
      with gui.nix's positive assertion -- either half alone could pass for
      the wrong reason (a typo'd path that never existed on either build).
    '';
    nmt.script = ''
      assertPathNotExists home-files/.config/alacritty/alacritty.toml
      assertPathNotExists home-files/.config/alacritty/keybindings.toml
    '';
  };
}
