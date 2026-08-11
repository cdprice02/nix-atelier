{
  pkgs,
  lib,
  options,
  ...
}:
let
  compat = import ./lib/hm-compat.nix { inherit lib options; };
  guiBase = import ./lib/gui-base.nix;
in
{
  home.packages = with pkgs; [
    obsidian
  ];

  programs = {
    alacritty = {
      enable = true;
      settings = {
        window = {
          opacity = guiBase.alacritty.windowOpacity;
          decorations = "none";
        };
        inherit (guiBase.alacritty) font;
        colors = {
          primary = {
            background = "#1e1e1e";
            foreground = "#d4d4d4";
          };
        };
      };
    };

    vscode.enable = true;

    # credential.helper for Linux GUI machines
    git = compat.gitConfig (
      guiBase.git
      // {
        credential.helper = lib.mkForce "store";
      }
    );
  };
}
