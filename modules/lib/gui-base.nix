# Shared base for gui-linux.nix and gui-darwin.nix. Packages, the vscode
# toggle, the alacritty theme/colors/font/opacity, and the git difftool/
# mergetool wiring are identical across both; only credential.helper (git)
# and decorations/option_as_alt (alacritty) genuinely differ, so each caller
# merges its own platform-specific bits around this rather than repeating
# the rest.
{ pkgs }:
{
  packages = [ pkgs.obsidian ];
  vscodeEnable = true;

  git = {
    diff.tool = "vscode";
    merge.tool = "vscode";
    difftool."vscode".cmd = "code --wait --diff $LOCAL $REMOTE";
    mergetool."vscode".cmd = "code --wait $MERGED";
  };

  alacritty = {
    # Home Manager resolves this against pkgs.alacritty-theme (hardcoded in
    # the module, not itself configurable) and imports it automatically.
    # Both platforms use it now; previously only darwin did, and Linux
    # hand-wrote a plain dark gray (#1e1e1e/#d4d4d4) that wasn't actually an
    # approximation of rose_pine's real colors (#191724/#e0def4) at all,
    # just an unrelated palette that happened to also be dark.
    theme = "rose_pine";
    # Overrides layered on top of the imported theme (a local `colors` table
    # always wins over an imported one for any key both define): rose_pine's
    # own background reads as too purple-tinted at normal contrast on this
    # setup. background is the darkest tier; selection.background is the
    # lighter tier shown for selected text, matching rose_pine's own
    # base/overlay convention rather than picking arbitrary values.
    colors = {
      primary.background = "#1a1921";
      selection.background = "#1e1d25";
    };
    windowOpacity = 0.9;
    font = {
      size = 14;
      normal.family = "Fira Code";
    };
  };
}
