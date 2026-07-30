{
  pkgs,
  lib,
  options,
  ...
}: let
  tmuxBase = import ../lib/tmux-base.nix;
  compat = import ../lib/hm-compat.nix {inherit lib options;};
in {
  home.packages = with pkgs; [
    # Dev tools
    gh
    glab
    difftastic
    pre-commit
    nixd
    duckdb
    hyperfine
    qmk
    # tmux package provided by programs.tmux below
  ];

  programs = {
    tmux = tmuxBase // {historyLimit = 10000;};

    # A `git difftool -t difftastic` entry, not a `diff.tool` default: GUI
    # profiles already default to vscode (gui-darwin.nix/gui-linux.nix), and
    # headless dev profiles have no GUI difftool to fall back to at all. This
    # adds an explicit option that works either way without touching either
    # default.
    git = compat.gitConfig {
      difftool."difftastic".cmd = "difft $LOCAL $REMOTE";
    };
  };
}
