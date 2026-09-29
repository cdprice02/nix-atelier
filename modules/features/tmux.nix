# Sole owner of tmux configuration: no other feature may set a tmux option.
# Two features setting conflicting values (e.g. different historyLimit) is a
# hard eval error the instant both are in the same profile -- an int option
# can't have two definitions at once. One feature, one value, enforces that
# structurally rather than by convention.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Default search roots: ~/repos, this framework's own checkout (whose
  # config/ submodules come along with it, see below), and every private
  # config repo machine.nix clones (atelier.configRepos, keyed by the path
  # under $HOME).
  defaultRoots = lib.concatStringsSep ":" (
    [
      "$HOME/repos"
      config.atelier.checkoutPath
    ]
    ++ map (path: "$HOME/${path}") (builtins.attrNames config.atelier.configRepos)
  );

  # ThePrimeagen's session-per-project flow: fuzzy-pick a project directory,
  # then create-or-attach a session named after it. Each entry of the
  # colon-separated TMUX_SESSIONIZER_DIRS is offered directly, along with
  # every submodule it declares, when it is a git repo itself; otherwise its
  # immediate subdirectories are. An explicit directory argument skips the
  # picker.
  sessionizer = pkgs.writeShellApplication {
    name = "tmux-sessionizer";
    runtimeInputs = with pkgs; [
      fd
      fzf
      git
      tmux
    ];
    text = ''
      IFS=: read -r -a roots <<< "''${TMUX_SESSIONIZER_DIRS:-${defaultRoots}}"

      if [[ $# -eq 1 ]]; then
        selected="$1"
      else
        candidates() {
          local root sm_path
          for root in "''${roots[@]}"; do
            [[ -d "$root" ]] || continue
            if [[ -e "$root/.git" ]]; then
              printf '%s\n' "$root"
              if [[ -f "$root/.gitmodules" ]]; then
                git config --file "$root/.gitmodules" --get-regexp '\.path$' \
                  | while read -r _ sm_path; do
                    if [[ -d "$root/$sm_path" ]]; then
                      printf '%s\n' "$root/$sm_path"
                    fi
                  done
              fi
            else
              fd --type d --min-depth 1 --max-depth 1 --hidden --exclude .git . "$root"
            fi
          done
        }
        selected="$(candidates | sed 's:/$::' | fzf --prompt 'session> ' || true)"
      fi

      [[ -n "$selected" ]] || exit 0

      # tmux session names can't contain '.' or ':'.
      name="$(basename "$selected" | tr '.:' '__')"

      if ! tmux has-session -t "=$name" 2>/dev/null; then
        tmux new-session -d -s "$name" -c "$selected"
      fi

      if [[ -n "''${TMUX:-}" ]]; then
        tmux switch-client -t "=$name"
      else
        tmux attach-session -t "=$name"
      fi
    '';
  };
in
{
  home.packages = [ sessionizer ];

  programs.tmux = {
    enable = true;
    keyMode = "vi";
    mouse = true;
    # tmux-256color rather than screen-256color: it describes italics and
    # true color correctly, which Neovim's colorschemes and :checkhealth both
    # expect inside tmux.
    terminal = "tmux-256color";
    # Esc reaches Neovim immediately instead of waiting to see whether it
    # starts an Alt-key sequence.
    escapeTime = 0;
    # Lets Neovim notice focus changes (autoread, gitsigns refresh).
    focusEvents = true;
    historyLimit = 50000;
    extraConfig = ''
      # The outer terminal (Windows Terminal, Alacritty) supports 24-bit
      # color; tmux only passes it through if told so.
      set -as terminal-features ",xterm-256color:RGB,alacritty:RGB"
      # Copies in tmux and in Neovim (OSC 52) reach the outer terminal's
      # system clipboard, including the Windows clipboard from WSL.
      set -g set-clipboard on

      set -g status-style bg=black,fg=white
      set -g status-left  "#[fg=green]#S "
      set -g status-right "#[fg=yellow]%H:%M"
      bind | split-window -h
      bind - split-window -v

      # Vim-style copy mode: v starts a selection, y copies it.
      bind -T copy-mode-vi v send-keys -X begin-selection
      bind -T copy-mode-vi y send-keys -X copy-selection-and-cancel

      bind f new-window ${sessionizer}/bin/tmux-sessionizer
      # Claude Code beside the current pane, in the same directory.
      bind C split-window -h -c "#{pane_current_path}" claude
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
