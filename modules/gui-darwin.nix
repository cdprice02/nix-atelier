{
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    obsidian
  ];

  # Raw TOML for Cmd/Option+arrow bindings. The chars values are literal
  # control-character bytes (Ctrl-A, Ctrl-E, Ctrl-U, ESC-b, ESC-f) — Nix
  # heredoc strings do not support \u escapes, so the bytes are embedded
  # directly. Alacritty reads chars as a raw byte sequence, not TOML escapes.
  home.file.".config/alacritty/keybindings.toml".text = ''
    [[keyboard.bindings]]
    key = "Left"
    mods = "Command"
    chars = ""

    [[keyboard.bindings]]
    key = "Right"
    mods = "Command"
    chars = ""

    [[keyboard.bindings]]
    key = "Back"
    mods = "Command"
    chars = ""

    [[keyboard.bindings]]
    key = "Left"
    mods = "Option"
    chars = "b"

    [[keyboard.bindings]]
    key = "Right"
    mods = "Option"
    chars = "f"
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
    git.extraConfig.credential.helper = lib.mkForce "osxkeychain";
  };
}
