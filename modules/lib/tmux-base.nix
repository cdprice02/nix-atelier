# Shared base tmux config: the single source for both features/dev-tools.nix
# and features/ops.nix. Each caller merges in its own historyLimit and
# extends extraConfig.
{
  enable = true;
  keyMode = "vi";
  mouse = true;
  terminal = "screen-256color";
  extraConfig = ''
    set -g status-style bg=black,fg=white
    set -g status-left  "#[fg=green]#S "
    set -g status-right "#[fg=yellow]%H:%M"
    bind | split-window -h
    bind - split-window -v
  '';
}
