{ user, ... }:
{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Define user for Home Manager compatibility
  users.users.${user.username} = {
    name = user.username;
    home = "/Users/${user.username}";
    description = user.username;
  };

  programs.zsh.enable = true;

  # Enable TouchID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      # Deliberately "none", which was "zap" until Homebrew 7.0 removed the
      # `--cleanup` switch that nix-darwin's zap/uninstall settings compile
      # down to. `brew bundle --file=... --cleanup --zap` now aborts with
      # "Calling the `--cleanup` switch is disabled! There is no
      # replacement.", and because the Homebrew step sits near the end of
      # darwin activation, that failure left the system profile advanced to
      # the new generation while /run/current-system still pointed at the
      # old one and Home Manager's user activation never ran at all.
      #
      # Not fixable by moving the nix-darwin pin: x86_64-darwin is held at
      # 25.05 on purpose (see the input-pairing table in CLAUDE.md), and
      # Homebrew is an unpinned external that updates itself during
      # activation regardless of which nix-darwin generates the command.
      #
      # The cost is that Homebrew is no longer declarative here: a formula
      # or cask removed from the lists below stays installed instead of
      # being uninstalled. `brew bundle cleanup --force` is the equivalent,
      # but it uninstalls anything absent from the Brewfile, so it is left
      # as a deliberate manual step rather than wired into every switch.
      cleanup = "none";
    };
    brews = [
      "screenresolution"
    ];
    casks = [
      "logitech-options"
      "copilot-cli@prerelease"
    ];
  };

  system = {
    primaryUser = user.username;

    defaults = {
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

    stateVersion = 6;
  };
}
