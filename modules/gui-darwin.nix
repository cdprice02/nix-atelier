{
  pkgs,
  lib,
  options,
  ...
}:
let
  compat = import ./lib/hm-compat.nix { inherit lib options; };
  guiBase = import ./lib/gui-base.nix { inherit pkgs; };
in
{
  home = {
    inherit (guiBase) packages;

    # Home Manager installs GUI apps (obsidian above, plus alacritty/vscode
    # below via their own programs.* modules) as symlinks under
    # ~/Applications/Home Manager Apps, pointing into the Nix store.
    # Spotlight does not index symlinks into an unindexed path, so these
    # apps are invisible to Spotlight, Launchpad and Finder search even
    # though `ls` shows them fine and the paths look correct.
    #
    # mkalias writes real macOS alias files, which Spotlight does follow.
    # Evaluated mac-app-util (a purpose-built flake for exactly this
    # problem, also handling Dock-pinning) as the alternative and rejected
    # it: its package fails to *build* on x86_64-darwin (sbcl, its Common
    # Lisp dependency, is marked broken there in nixpkgs) even though it
    # evaluates cleanly. That pair is a real, actively used target here,
    # not a stub -- see the x86_64-darwin pin in this repo's own
    # input-pairing invariant.
    #
    # Wipes and regenerates the alias directory every switch rather than
    # diffing individual files: cheap (a handful of tiny alias files), and
    # it means a removed app's stale alias cannot linger.
    activation.spotlightAliases = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      srcDir="$HOME/Applications/Home Manager Apps"
      destDir="$HOME/Applications/Home Manager Trampolines"
      if [ -d "$srcDir" ]; then
        $DRY_RUN_CMD rm -rf "$destDir"
        $DRY_RUN_CMD mkdir -p "$destDir"
        for app in "$srcDir"/*.app; do
          [ -e "$app" ] || continue
          $DRY_RUN_CMD ${pkgs.mkalias}/bin/mkalias "$app" "$destDir/$(basename "$app")"
        done
      fi
    '';

    # Cmd/Option+arrow keybindings using TOML \uXXXX escapes (literal control
    # bytes are invalid TOML). Identities:
    #   Cmd+Left  -> \u0001 (Ctrl-A) = readline beginning-of-line
    #   Cmd+Right -> \u0005 (Ctrl-E) = readline end-of-line
    #   Cmd+Back  -> \u0015 (Ctrl-U) = readline kill-to-beginning-of-line
    #   Opt+Left  -> \u001bb (ESC b)  = readline backward-word
    #   Opt+Right -> \u001bf (ESC f)  = readline forward-word
    file.".config/alacritty/keybindings.toml".text = ''
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
  };

  programs = {
    alacritty = {
      enable = true;
      inherit (guiBase.alacritty) theme;
      settings = {
        window = {
          opacity = guiBase.alacritty.windowOpacity;
          decorations = "buttonless";
          option_as_alt = "Both";
        };
        inherit (guiBase.alacritty) font colors;
        general.import = [
          "~/.config/alacritty/keybindings.toml"
        ];
      };
    };
    vscode.enable = guiBase.vscodeEnable;
    git = compat.gitConfig (
      guiBase.git
      // {
        credential.helper = lib.mkForce "osxkeychain";
      }
    );
  };
}
