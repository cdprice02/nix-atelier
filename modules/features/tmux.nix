# Sole owner of tmux configuration: no other feature may set a tmux option.
# Two features setting conflicting values (e.g. different historyLimit) is a
# hard eval error the instant both are in the same profile -- an int option
# can't have two definitions at once. One feature, one value, enforces that
# structurally rather than by convention.
{ pkgs, ... }:
{
  programs.tmux = {
    enable = true;
    keyMode = "vi";
    mouse = true;
    terminal = "screen-256color";
    historyLimit = 50000;
    extraConfig = ''
      set -g status-style bg=black,fg=white
      set -g status-left  "#[fg=green]#S "
      set -g status-right "#[fg=yellow]%H:%M"
      bind | split-window -h
      bind - split-window -v
    '';
    # tmux-continuum wraps tmux-resurrect for automatic save/restore: both
    # are required; continuum alone does not save/restore sessions itself.
    # @continuum-restore is attached to continuum's own plugin entry, not
    # the general extraConfig above: home-manager renders each plugin's own
    # extraConfig immediately before that plugin's run-shell line, but the
    # top-level extraConfig only after every plugin's run-shell line.
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
