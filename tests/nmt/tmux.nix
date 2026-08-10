# tmux is a single-owner contract now (issue #53): features/tmux.nix is the
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
}
