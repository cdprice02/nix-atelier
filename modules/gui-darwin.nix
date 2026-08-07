{
  pkgs,
  lib,
  options,
  ...
}: let
  compat = import ./lib/hm-compat.nix {inherit lib options;};
  guiBase = import ./lib/gui-base.nix;
in {
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
      # Home Manager resolves this against pkgs.alacritty-theme (hardcoded
      # in the module, not itself configurable) and imports it automatically.
      theme = "rose_pine";
      settings = {
        window = {
          opacity = guiBase.alacritty.windowOpacity;
          decorations = "buttonless";
          option_as_alt = "Both";
        };
        inherit (guiBase.alacritty) font;
        general.import = [
          "~/.config/alacritty/keybindings.toml"
        ];
      };
    };
    vscode.enable = true;
    git = compat.gitConfig (guiBase.git
      // {
        credential.helper = lib.mkForce "osxkeychain";
      });
  };
}
