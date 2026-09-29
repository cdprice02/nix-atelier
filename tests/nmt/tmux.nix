# tmux is a single-owner contract now: features/tmux.nix is the
# only feature allowed to touch programs.tmux, replacing the old two-tier
# (dev-tools.nix/ops.nix) split that carried two different historyLimit
# values -- a hard eval error the instant both landed in the same profile.
# One value, asserted once, is the positive form of that invariant.
{
  tmux-history-limit-and-continuum-restore = {
    nmt.description = ''
      Pins the single historyLimit value, and the continuum-restore
      load-order subtlety features/tmux.nix documents: @continuum-restore is
      attached to continuum's own plugin extraConfig, not the top-level one,
      because home-manager renders each plugin's extraConfig immediately
      before that plugin's run-shell line, but top-level extraConfig only
      after every plugin's run-shell line -- setting it there would be a
      load-order race instead of a guarantee. Invisible in the rendered file
      unless you know to look for which extraConfig block it landed in.
    '';
    nmt.script = ''
      # home-manager's tmux module column-aligns "set -g <opt>  <value>" within
      # a block, so the literal run of spaces between history-limit and 50000
      # isn't stable against an unrelated option being added nearby -- match
      # on whitespace instead of a fixed gap.
      assertFileRegex home-files/.config/tmux/tmux.conf 'history-limit[[:space:]][[:space:]]*50000'
      assertFileContains home-files/.config/tmux/tmux.conf "set -g @continuum-restore 'on'"
    '';
  };

  tmux-neovim-friendly = {
    nmt.description = ''
      The settings Neovim's :checkhealth asks for inside tmux: a terminal
      type that describes true color, RGB passthrough for the outer
      terminal, no Esc delay, and focus events. Plus the clipboard and
      sessionizer bindings the neovim feature's workflow relies on.
    '';
    nmt.script = ''
      conf=home-files/.config/tmux/tmux.conf
      assertFileRegex "$conf" 'default-terminal[[:space:]][[:space:]]*"tmux-256color"'
      assertFileContains "$conf" 'set -as terminal-features ",xterm-256color:RGB,alacritty:RGB"'
      assertFileRegex "$conf" 'escape-time[[:space:]][[:space:]]*0$'
      assertFileRegex "$conf" 'focus-events[[:space:]][[:space:]]*on'
      assertFileContains "$conf" 'set -g set-clipboard on'
      assertFileContains "$conf" 'bind -T copy-mode-vi v send-keys -X begin-selection'
      assertFileContains "$conf" 'bind -T copy-mode-vi y send-keys -X copy-selection-and-cancel'
      assertFileRegex "$conf" '^bind f new-window .*/bin/tmux-sessionizer$'
      assertFileContains "$conf" 'bind C split-window -h -c "#{pane_current_path}" claude'
    '';
  };
}
