{pkgs, ...}: let
  tmuxBase = import ../lib/tmux-base.nix;
in {
  home.packages = with pkgs; [
    # Dev tools
    gh
    pre-commit
    tmux
    qmk
  ];

  programs.tmux = tmuxBase // {historyLimit = 10000;};
}
