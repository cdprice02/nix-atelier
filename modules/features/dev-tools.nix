{pkgs, ...}: let
  tmuxBase = import ../lib/tmux-base.nix;
in {
  home.packages = with pkgs; [
    # Dev tools
    gh
    pre-commit
    qmk
    # tmux package provided by programs.tmux below
  ];

  programs.tmux = tmuxBase // {historyLimit = 10000;};
}
