{ pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    obsidian
  ];

  programs.alacritty = {
    enable   = true;
    settings = {
      window = {
        opacity       = 0.9;
        decorations   = "buttonless";
        option_as_alt = "Both";
      };
      font = {
        size          = 14;
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

  # Raw TOML for Cmd+arrow bindings. Written via home.file.text so the
  # \uXXXX sequences are literal text in the TOML file (valid TOML Unicode escapes).
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

  programs.vscode.enable = true;

  programs.git.extraConfig.credential.helper = lib.mkForce "osxkeychain";
}
