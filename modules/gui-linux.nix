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
