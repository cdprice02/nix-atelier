{pkgs, ...}: let
  tmuxBase = import ../lib/tmux-base.nix;
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
      # @continuum-restore is attached to continuum's own plugin entry, not
      # the general extraConfig below: home-manager renders each plugin's
      # own extraConfig immediately before that plugin's run-shell line, but
      # the top-level extraConfig only after every plugin's run-shell line.
      # Continuum reads @continuum-restore itself at run-shell time (in a
      # backgrounded restore check), so setting it from the top-level
      # extraConfig would be a load-order race instead of a guarantee.
      plugins = [
        pkgs.tmuxPlugins.resurrect
        {
          plugin = pkgs.tmuxPlugins.continuum;
          extraConfig = "set -g @continuum-restore 'on'";
        }
      ];
    };
}
