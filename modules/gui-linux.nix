{
  pkgs,
  lib,
  options,
  ...
}: let
  compat = import ./lib/hm-compat.nix {inherit lib options;};
in {
  home.packages = with pkgs; [
    obsidian
  ];

  programs = {
    alacritty = {
      enable = true;
      settings = {
        window = {
          opacity = 0.9;
          decorations = "none";
        };
        font = {
          size = 14;
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

    vscode.enable = true;

    # credential.helper for Linux GUI machines
    git = compat.gitConfig {
      credential.helper = lib.mkForce "store";
      diff.tool = "vscode";
      merge.tool = "vscode";
      difftool."vscode".cmd = "code --wait --diff $LOCAL $REMOTE";
      mergetool."vscode".cmd = "code --wait $MERGED";
    };
  };
}
