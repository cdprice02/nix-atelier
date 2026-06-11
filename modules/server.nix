{ pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    rsync
    tree
    ncdu
    htop
    # tmux package provided by programs.tmux below
  ];

  programs.tmux = {
    enable       = true;
    keyMode      = "vi";
    mouse        = true;
    terminal     = "screen-256color";
    historyLimit = 50000;  # larger than dev — server sessions are long-lived
    extraConfig  = ''
      set -g status-style bg=black,fg=white
      set -g status-left  "#[fg=green]#S "
      set -g status-right "#[fg=yellow]%H:%M"
      bind | split-window -h
      bind - split-window -v
      # Persist sessions across disconnect
      set -g @continuum-restore 'on'
    '';
  };
}
