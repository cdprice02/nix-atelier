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

  inherit (config.atelier.tmux) sshSessions;

  # ThePrimeagen's session-per-project flow: fuzzy-pick a project directory,
  # then create-or-attach a session named after it. Each entry of the
  # colon-separated TMUX_SESSIONIZER_DIRS is offered directly, along with
  # every submodule it declares, when it is a git repo itself; otherwise its
  # immediate subdirectories are. An explicit directory argument skips the
  # picker. Three entries sit outside that flow: "~ (home)" is the `main`
  # session at $HOME, each atelier.tmux.sshSessions host opens a session of
  # that name running ssh, and a typed name that matches nothing becomes a
  # scratch session at $HOME. `--home` jumps straight to `main`.
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
      ssh_hosts=(${lib.escapeShellArgs sshSessions})
      home_entry="~ (home)"
      ssh_prefix="ssh: "

      # Create the session detached if it is missing, then switch to it.
      # Any further arguments are the session's initial command, which
      # also becomes its default-command: new windows and splits run it too.
      # Re-set on every open because resurrect restores panes but not
      # session options.
      open_session() {
        local name="$1" dir="$2"
        shift 2
        # tmux session names can't contain '.' or ':'.
        name="$(printf '%s' "$name" | tr '.:' '__')"
        if ! tmux has-session -t "=$name" 2>/dev/null; then
          tmux new-session -d -s "$name" -c "$dir" "$@"
        fi
        if [[ $# -gt 0 ]]; then
          tmux set-option -t "=$name:" default-command "$*"
        fi
        if [[ -n "''${TMUX:-}" ]]; then
          tmux switch-client -t "=$name"
        else
          tmux attach-session -t "=$name"
        fi
      }

      if [[ ''${1:-} == --home ]]; then
        open_session main "$HOME"
        exit 0
      fi

      if [[ $# -eq 1 ]]; then
        open_session "$(basename "$1")" "$1"
        exit 0
      fi

      candidates() {
        local root sm_path host
        printf '%s\n' "$home_entry"
        for host in "''${ssh_hosts[@]}"; do
          printf '%s%s\n' "$ssh_prefix" "$host"
        done
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

      # --print-query puts the typed text on line 1 and the highlighted
      # match, if any, on line 2; fzf exits 1 on no match but still prints.
      { read -r query || true; read -r selected || true; } \
        < <(candidates | sed 's:/$::' | fzf --prompt 'session> ' --print-query || true)

      if [[ -n "$selected" ]]; then
        case "$selected" in
          "$home_entry") open_session main "$HOME" ;;
          "$ssh_prefix"*)
            host="''${selected#"$ssh_prefix"}"
            # exec $SHELL keeps the window (and the error) after a failed or
            # finished ssh, e.g. when the VPN is down.
            open_session "$host" "$HOME" "ssh $host; exec \$SHELL"
            ;;
          *) open_session "$(basename "$selected")" "$selected" ;;
        esac
      elif [[ -n "$query" ]]; then
        open_session "$query" "$HOME"
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
      bind | split-window -h
      bind - split-window -v

      # Vim-style copy mode: v starts a selection, y copies it.
      bind -T copy-mode-vi v send-keys -X begin-selection
      bind -T copy-mode-vi y send-keys -X copy-selection-and-cancel

      bind f new-window ${sessionizer}/bin/tmux-sessionizer
      # Back to the `main` session at $HOME, creating it if needed.
      bind h run-shell "${sessionizer}/bin/tmux-sessionizer --home"
      # Claude Code beside the current pane, in the same directory.
      bind C split-window -h -c "#{pane_current_path}" claude
      # lazygit over everything, in the current pane's directory.
      bind g display-popup -E -w 90% -h 90% -d "#{pane_current_path}" lazygit
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
    #
    # status-right is set in resurrect's entry, ahead of continuum's
    # run-shell, for the same reason: continuum appends its autosave hook to
    # whatever status-right holds when it loads, so a later `set -g
    # status-right` silently deletes the hook and nothing is ever saved.
    plugins = [
      {
        plugin = pkgs.tmuxPlugins.resurrect;
        extraConfig = ''
          set -g status-right "#[fg=yellow]%H:%M"
          set -g @resurrect-capture-pane-contents 'on'
          # Added to resurrect's default list (vi, vim, nvim, man, less, ...).
          # A restore on a host whose VPN is down just leaves a shell.
          set -g @resurrect-processes 'ssh'
        '';
      }
      {
        plugin = pkgs.tmuxPlugins.continuum;
        extraConfig = "set -g @continuum-restore 'on'";
      }
    ];
  };
}
