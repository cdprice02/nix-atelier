{
  config,
  pkgs,
  lib,
  user,
  context,
  ...
}: let
  homeDir = config.home.homeDirectory;

  # Both paths are tried: single-user Nix (common on WSL2/macOS standalone) sources
  # ~/.nix-profile/...; multi-user Nix daemon sources /nix/var/nix/profiles/...
  # Only the installed variant will exist; the other source is a no-op.
  nixProfileInit = ''
    # Single-user Nix
    if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
      . "$HOME/.nix-profile/etc/profile.d/nix.sh"
    fi
    # Multi-user Nix daemon
    if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
      . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    fi
  '';

  envLocalInit = ''
    if [ -f "$HOME/.config/secrets/env" ]; then
      source "$HOME/.config/secrets/env"
    fi
  '';
in {
  home = {
    inherit (user) username;
    # mkForce overrides HM's default homeDirectory derivation, which is unreliable
    # on WSL2 and non-standard Linux setups where /home may not match expectations.
    homeDirectory = lib.mkForce (
      if pkgs.stdenv.isDarwin
      then "/Users/${user.username}"
      else "/home/${user.username}"
    );

    sessionVariables = {
      EDITOR = "vim";
      CLAUDE_PROFILE = context;
    };

    # Binaries installed via `cargo install` outside Nix land here
    sessionPath = ["$HOME/.cargo/bin" "$HOME/.npm-global/bin"];

    packages = with pkgs; [
      # Fonts — used everywhere for terminal rendering and prompt icons
      fira-code
      nerd-fonts.fira-code

      # Home Manager — needed for setup across all profiles and devices
      pkgs.home-manager

      # just — task runner / discoverability layer (`just --list` shows all commands)
      just

      # CLI essentials
      jq
      ripgrep
      fd
      bat
      eza
      delta
      lazygit
      git-lfs
      wget
      btop
      neofetch
    ];

    activation = {
      # entryAfter writeBoundary — ~/.ssh must exist (written by HM) before ssh-keygen runs.
      sshKey = lib.hm.dag.entryAfter ["writeBoundary"] ''
        if [ ! -f "$HOME/.ssh/${user.sshKey}" ]; then
          $DRY_RUN_CMD mkdir -p "$HOME/.ssh"
          $DRY_RUN_CMD chmod 700 "$HOME/.ssh"
          $DRY_RUN_CMD ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -C "${user.email}" \
            -f "$HOME/.ssh/${user.sshKey}" -N ""
          echo "SSH key generated: ~/.ssh/${user.sshKey}"
          echo "Add to GitHub: https://github.com/settings/keys"
          cat "$HOME/.ssh/${user.sshKey}.pub"
        fi
      '';

      # For each entry in user.submodules, wire up a private remote in the
      # corresponding config/ submodule and check out a tracking branch.
      # Idempotent — skips if the remote already exists.
      # entryAfter writeBoundary — submodule dirs must be cloned before we can add remotes.
      # user.submodules = { claude = "git@github.com:you/private-claude.git"; };
      submoduleOverrides = lib.hm.dag.entryAfter ["writeBoundary"] (
        let
          submodules = user.submodules or {};
          git = "${pkgs.git}/bin/git";
          mkOverride = name: url: ''
            _sm_dir="$HOME/.nix-config/config/${name}"
            if [ -d "$_sm_dir/.git" ]; then
              _has_private=$(${git} -C "$_sm_dir" remote get-url private 2>/dev/null && echo yes || echo no)
              if [ "$_has_private" = "no" ]; then
                $DRY_RUN_CMD ${git} -C "$_sm_dir" remote add private "${url}"
                if $DRY_RUN_CMD ${git} -C "$_sm_dir" fetch private; then
                  $DRY_RUN_CMD ${git} -C "$_sm_dir" checkout -b work --track private/main \
                    || ${git} -C "$_sm_dir" checkout work
                  echo "submodule ${name}: private remote configured (${url})"
                else
                  echo "WARNING: submodule ${name}: fetch from private remote failed."
                  echo "  Ensure your SSH key is added to GitHub, then rerun: home-manager switch --flake ~/.nix-config --impure"
                  $DRY_RUN_CMD ${git} -C "$_sm_dir" remote remove private
                fi
              fi
            fi
          '';
        in
          lib.concatStrings (lib.mapAttrsToList mkOverride submodules)
      );
    };

    # Submodules under config/ are symlinked into HOME so tools find them at the
    # expected paths. mkOutOfStoreSymlink keeps them live-editable (not copied
    # into the Nix store), which is required for git-managed tool configs.
    file = {
      ".claude" = {
        source =
          config.lib.file.mkOutOfStoreSymlink
          "${config.home.homeDirectory}/.nix-config/config/claude";
      };
      ".copilot" = lib.mkIf (context == "personal") {
        source =
          config.lib.file.mkOutOfStoreSymlink
          "${config.home.homeDirectory}/.nix-config/config/copilot";
      };
    };

    stateVersion = "23.11";
  };

  programs = {
    # ── Shells ────────────────────────────────────────────────────────────────

    zsh = {
      enable = true;
      enableCompletion = true;
      # envExtra → .zshenv (sourced first, before .zshrc). Nix must be on PATH
      # before tool integrations (atuin, fnm, zoxide) evaluate their init hooks.
      envExtra = nixProfileInit;
      initContent =
        envLocalInit
        + ''
          # Word navigation: Alt/Option+arrow. Alacritty with option_as_alt sends
          # xterm-style sequences on macOS; Linux terminals send the same sequences.
          bindkey '^[[1;3D' backward-word
          bindkey '^[[1;3C' forward-word
          # Home/End keys (also covers Cmd+Left/Right via Alacritty keybindings.toml)
          bindkey '^[[H' beginning-of-line
          bindkey '^[[F' end-of-line
        '';
    };

    bash = {
      enable = true;
      enableCompletion = true;
      profileExtra = nixProfileInit;
      initExtra = envLocalInit;
    };

    # ── Prompt ────────────────────────────────────────────────────────────────

    starship = {
      enable = true;
      enableZshIntegration = true;
      enableBashIntegration = true;
      settings = {
        format = "$os$username$hostname$directory$git_branch$git_status$aws$rust$python$golang$nodejs$package$cmd_duration\n$character";

        aws = {
          format = "[$symbol$region]($style) ";
          force_display = false;
          region_aliases = {
            "us-east-1" = "va";
            "us-east-2" = "oh";
            "us-west-1" = "ca";
            "us-west-2" = "or";
            "af-south-1" = "cape";
            "ap-east-1" = "hk";
            "ap-south-1" = "mum";
            "ap-south-2" = "hyd";
            "ap-southeast-1" = "sg";
            "ap-southeast-2" = "syd";
            "ap-southeast-3" = "jkt";
            "ap-southeast-4" = "mel";
            "ap-southeast-5" = "my";
            "ap-southeast-6" = "nz";
            "ap-southeast-7" = "th";
            "ap-northeast-1" = "tok";
            "ap-northeast-2" = "kr";
            "ap-northeast-3" = "osk";
            "ap-east-2" = "tw";
            "ca-central-1" = "ca";
            "ca-west-1" = "cal";
            "cn-north-1" = "bj";
            "cn-northwest-1" = "nx";
            "eu-central-1" = "de";
            "eu-central-2" = "ch";
            "eu-north-1" = "se";
            "eu-south-1" = "it";
            "eu-south-2" = "es";
            "eu-west-1" = "ie";
            "eu-west-2" = "ldn";
            "eu-west-3" = "fr";
            "me-central-1" = "ae";
            "me-south-1" = "bh";
            "mx-central-1" = "mx";
            "sa-east-1" = "br";
            "us-gov-east-1" = "gov-e";
            "us-gov-west-1" = "gov-w";
          };
        };

        character = {
          success_symbol = "[❯](bold green)";
          error_symbol = "[❯](bold red)";
        };

        cmd_duration = {
          min_time = 2000;
          format = "took [$duration]($style) ";
          style = "bold yellow";
        };

        directory.truncation_length = 3;

        git_branch.symbol = "🌱 ";

        git_status = {
          ahead = "⇡\${count}";
          diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
          behind = "⇣\${count}";
        };

        hostname = {
          ssh_only = false;
          format = "[@](black)([$ssh_symbol]($style))[$hostname](bold blue) ";
        };

        os.disabled = false;

        package.format = "[$symbol$version]($style) ";

        username = {
          format = "[$user]($style)";
          show_always = true;
        };

        rust = {
          format = "via [$symbol($version)]($style) ";
          style = "bold red";
        };
        python = {
          format = "via [$symbol($version)]($style) ";
          style = "bold yellow";
        };
        golang = {
          format = "via [$symbol($version)]($style) ";
          style = "bold cyan";
        };
        nodejs = {
          format = "via [$symbol($version)]($style) ";
          style = "bold green";
        };

        # Disabled language modules
        buf.disabled = true;
        bun.disabled = true;
        c.disabled = true;
        cmake.disabled = true;
        cobol.disabled = true;
        crystal.disabled = true;
        daml.disabled = true;
        dart.disabled = true;
        deno.disabled = true;
        dotnet.disabled = true;
        elixir.disabled = true;
        elm.disabled = true;
        erlang.disabled = true;
        fennel.disabled = true;
        gleam.disabled = true;
        gradle.disabled = true;
        haskell.disabled = true;
        haxe.disabled = true;
        helm.disabled = true;
        java.disabled = true;
        julia.disabled = true;
        kotlin.disabled = true;
        lua.disabled = true;
        meson.disabled = true;
        nim.disabled = true;
        nix_shell.disabled = true;
        ocaml.disabled = true;
        odin.disabled = true;
        opa.disabled = true;
        perl.disabled = true;
        php.disabled = true;
        pulumi.disabled = true;
        purescript.disabled = true;
        quarto.disabled = true;
        raku.disabled = true;
        red.disabled = true;
        rlang.disabled = true;
        ruby.disabled = true;
        scala.disabled = true;
        solidity.disabled = true;
        swift.disabled = true;
        terraform.disabled = true;
        typst.disabled = true;
        vagrant.disabled = true;
        vlang.disabled = true;
        zig.disabled = true;
      };
    };

    # ── Shell tools ───────────────────────────────────────────────────────────

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    zoxide = {
      enable = true;
      enableZshIntegration = true;
      enableBashIntegration = true;
    };

    atuin = {
      enable = true;
      enableZshIntegration = true;
      enableBashIntegration = true;
    };

    fzf = {
      enable = true;
      enableZshIntegration = true;
      enableBashIntegration = true;
    };

    # ── Editor ────────────────────────────────────────────────────────────────

    vim = {
      enable = true;
      defaultEditor = true;
      settings = {
        number = true;
        relativenumber = true;
        tabstop = 2;
        shiftwidth = 2;
        expandtab = true;
      };
      extraConfig = ''
        syntax on
        set clipboard=unnamed
        set ignorecase
        set smartcase
      '';
    };

    # ── SSH ───────────────────────────────────────────────────────────────────
    # credential.helper is NOT set here — gui-darwin/gui-linux own that

    ssh = {
      enable = true;
      enableDefaultConfig = false;
      includes = ["~/.ssh/config.d/*"]; # work.nix writes stubs here
      matchBlocks = {
        "*" = {
          identityFile = "~/.ssh/${user.sshKey}";
          addKeysToAgent = "yes";
          extraOptions = lib.optionalAttrs pkgs.stdenv.isDarwin {
            UseKeychain = "yes";
          };
        };
        "github.com" = {
          user = "git";
          identitiesOnly = true;
        };
      };
    };

    # ── Git ───────────────────────────────────────────────────────────────────

    git = {
      enable = true;
      userName = user.name;
      userEmail = user.email;

      includes = [
        # self doesn't include submodule contents in the Nix store; use live path instead.
        # Safe because --impure is already required for user.nix.
        {path = "${homeDir}/.nix-config/config/git/gitalias/gitalias.txt";}
      ];

      ignores = [
        ".DS_Store"
        ".AppleDouble"
        ".LSOverride"
        ".env"
        ".env.local"
        "*.env"
        ".env.*"
        ".config/secrets/"
        "*.pyc"
        "__pycache__/"
        ".venv/"
        ".ipynb_checkpoints/"
        ".direnv/"
        "node_modules/"
        ".idea/"
        ".vscode/"
        "*.swp"
        "*.swo"
        "target/"
      ];

      extraConfig = {
        init.defaultBranch = "main";
        pull.rebase = false;
        push.default = "simple";
        push.autoSetupRemote = true;
        core.autocrlf = "input";
        # diff.tool and merge.tool are set by gui-darwin/gui-linux (where `code` is available)
        # credential.helper intentionally absent — set by gui-darwin or gui-linux
      };
    };
  };
}
