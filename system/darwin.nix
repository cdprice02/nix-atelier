{ pkgs, user, ... }:
{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Runs from the system launchd as root so it expires every profile's
  # generations, not just the invoking user's; each Home Manager switch
  # otherwise leaves a generation, and its closure, pinned forever.
  nix.gc = {
    automatic = true;
    interval = {
      Weekday = 0;
      Hour = 3;
      Minute = 15;
    };
    options = "--delete-older-than 14d";
  };

  # Define user for Home Manager compatibility
  users.users.${user.username} = {
    name = user.username;
    home = "/Users/${user.username}";
    description = user.username;
  };

  programs.zsh.enable = true;

  # macOS ships no `timeout`, and Claude Code shells out to it often. The
  # Homebrew coreutils formula installs it only as `gtimeout` (the unprefixed
  # names live in libexec/gnubin, which would shadow every BSD tool if put on
  # PATH), so expose just this one command. The aisk/tap `timeout` formula was
  # rejected: it is a source-built Haskell binary with no x86_64-darwin bottle.
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "timeout" ''exec gtimeout "$@"'')
  ];

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
      "coreutils"
      "screenresolution"
    ];
    casks = [
      "logitech-options"
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
