# Shared base for gui-linux.nix and gui-darwin.nix. The git difftool/mergetool
# wiring and alacritty font/opacity are identical across both; only
# credential.helper (git) and decorations/theme/option_as_alt (alacritty)
# genuinely differ, so each caller merges its own platform-specific bits
# around these rather than repeating them.
{
  git = {
    diff.tool = "vscode";
    merge.tool = "vscode";
    difftool."vscode".cmd = "code --wait --diff $LOCAL $REMOTE";
    mergetool."vscode".cmd = "code --wait $MERGED";
  };

  alacritty = {
    windowOpacity = 0.9;
    font = {
      size = 14;
      normal.family = "Fira Code";
    };
  };
}
