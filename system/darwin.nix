{ pkgs, system, user, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.primaryUser = user.username;

  # Define user for Home Manager compatibility
  users.users.${user.username} = {
    name = user.username;
    home = "/Users/${user.username}";
    description = user.username;
  };

  programs.zsh.enable = true;

  # Enable TouchID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      AppleShowAllExtensions = true;
      ApplePressAndHoldEnabled = false;
      KeyRepeat = 6;
      InitialKeyRepeat = 15;
      "com.apple.mouse.tapBehavior" = 1;
    };
    dock = {
      autohide = false;
      show-recents = false;
      launchanim = true;
      mru-spaces = false;
      orientation = "bottom";
      tilesize = 48;
    };
    finder = {
      AppleShowAllExtensions = true;
      AppleShowAllFiles = true;
      CreateDesktop = false;
      FXPreferredViewStyle = "clmv";
      NewWindowTarget = "Home";
      ShowPathbar = true;
    };
    loginwindow.LoginwindowText = "May the odds be ever in your favor.";
    menuExtraClock.ShowSeconds = true;
    screensaver.askForPasswordDelay = 10;
  };

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
    };
    brews = [
      "screenresolution"
    ];
    casks = [
      "logitech-options"
      "copilot-cli@prerelease"
    ];
  };

  system.stateVersion = 6;
}
