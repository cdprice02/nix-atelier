{pkgs, ...}: let
  tmuxBase = import ./lib/tmux-base.nix;
in {
  home.packages = with pkgs; [
    rsync
    tree
    ncdu
    htop
    # tmux package provided by programs.tmux below
  ];

  programs.tmux =
    tmuxBase
    // {
      historyLimit = 50000; # larger than dev — server sessions are long-lived
      # tmux-continuum wraps tmux-resurrect for automatic save/restore — both
      # are required; continuum alone does not save/restore sessions itself.
      plugins = [pkgs.tmuxPlugins.resurrect pkgs.tmuxPlugins.continuum];
      extraConfig =
        tmuxBase.extraConfig
        + ''
          # Persist sessions across disconnect
          set -g @continuum-restore 'on'
        '';
    };
}
