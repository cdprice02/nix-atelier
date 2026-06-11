{ pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    obsidian
  ];

  programs.alacritty = {
    enable   = true;
    settings = {
      window = {
        opacity     = 0.9;
        decorations = "buttonless";
      };
      font = {
        size          = 14;
        normal.family = "Fira Code";
      };
      colors = {
        primary = {
          background = "#1e1e1e";
          foreground = "#d4d4d4";
        };
      };
    };
  };

  programs.vscode.enable = true;

  # credential.helper for macOS
  programs.git.extraConfig.credential.helper = lib.mkForce "osxkeychain";
}
