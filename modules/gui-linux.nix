{
  pkgs,
  lib,
  options,
  ...
}:
let
  compat = import ./lib/hm-compat.nix { inherit lib options; };
  guiBase = import ./lib/gui-base.nix { inherit pkgs; };
in
{
  home.packages = guiBase.packages;

  # Without it fontconfig never looks in the Nix profile, so alacritty
  # can't find the fonts above and silently falls back to a system font.
  fonts.fontconfig.enable = true;

  programs = {
    alacritty = {
      enable = true;
      inherit (guiBase.alacritty) theme;
      settings = {
        window = guiBase.alacritty.window // {
          decorations = "none";
        };
        inherit (guiBase.alacritty)
          font
          colors
          scrolling
          selection
          mouse
          cursor
          ;
      };
    };

    vscode.enable = guiBase.vscodeEnable;

    # credential.helper for Linux GUI machines
    git = compat.gitConfig (
      guiBase.git
      // {
        credential.helper = lib.mkForce "store";
      }
    );
  };
}
