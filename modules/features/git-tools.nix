{
  lib,
  pkgs,
  options,
  ...
}: let
  compat = import ../lib/hm-compat.nix {inherit lib options;};
in {
  home.packages = with pkgs; [
    gh
    glab
    difftastic
    git-filter-repo
    pre-commit
  ];

  # A `git difftool -t difftastic` entry, not a `diff.tool` default: GUI
  # profiles already default to vscode (gui-darwin.nix/gui-linux.nix), and
  # headless dev profiles have no GUI difftool to fall back to at all. This
  # adds an explicit option that works either way without touching either
  # default.
  programs.git = compat.gitConfig {
    difftool."difftastic".cmd = "difft $LOCAL $REMOTE";
  };
}
