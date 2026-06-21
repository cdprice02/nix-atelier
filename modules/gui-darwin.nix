{
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    obsidian
  ];

  # Cmd/Option+arrow keybindings using TOML \uXXXX escapes (literal control
  # bytes are invalid TOML). Identities:
  #   Cmd+Left  -> \u0001 (Ctrl-A) = readline beginning-of-line
  #   Cmd+Right -> \u0005 (Ctrl-E) = readline end-of-line
  #   Cmd+Back  -> \u0015 (Ctrl-U) = readline kill-to-beginning-of-line
  #   Opt+Left  -> \u001bb (ESC b)  = readline backward-word
  #   Opt+Right -> \u001bf (ESC f)  = readline forward-word
  home.file.".config/alacritty/keybindings.toml".text = ''
    [[keyboard.bindings]]
    key = "Left"
    mods = "Command"
    chars = "\u0001"

    [[keyboard.bindings]]
    key = "Right"
    mods = "Command"
    chars = "\u0005"

    [[keyboard.bindings]]
    key = "Back"
    mods = "Command"
    chars = "\u0015"

    [[keyboard.bindings]]
    key = "Left"
    mods = "Option"
    chars = "\u001bb"

    [[keyboard.bindings]]
    key = "Right"
    mods = "Option"
    chars = "\u001bf"
  '';

  programs = {
    alacritty = {
      enable = true;
      settings = {
        window = {
          opacity = 0.9;
          decorations = "buttonless";
          option_as_alt = "Both";
        };
        font = {
          size = 14;
          normal.family = "Fira Code";
        };
        colors = {
          primary = {
            background = "#1e1e1e";
            foreground = "#d4d4d4";
          };
        };
        general.import = [
          "rose-pine/dist/rose-pine.toml"
          "~/.config/alacritty/keybindings.toml"
        ];
      };
    };
    vscode.enable = true;
    git.extraConfig = {
      credential.helper = lib.mkForce "osxkeychain";
      diff.tool = "vscode";
      merge.tool = "vscode";
      difftool."vscode".cmd = "code --wait --diff $LOCAL $REMOTE";
      mergetool."vscode".cmd = "code --wait $MERGED";
    };
  };
}
