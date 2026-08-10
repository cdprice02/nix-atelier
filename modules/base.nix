{
  config,
  options,
  pkgs,
  lib,
  user,
  ...
}: let
  homeDir = config.home.homeDirectory;

  # Emits whichever option spelling the evaluating home-manager has: the
  # rolling input (Linux/WSL2 + aarch64-darwin) tracks HM master, which has
  # renamed several of the options set below; x86_64-darwin is pinned to HM
  # 25.05, which predates those renames. See modules/lib/hm-compat.nix.
  compat = import ./lib/hm-compat.nix {inherit lib options;};

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

    # Runtime-tool PATH and writable install prefixes (cargo/npm/uv/bun/pixi)
    # live in modules/env.nix, imported alongside this module for every profile.

    packages = with pkgs; [
      # Home Manager: needed for setup across all profiles and devices
      pkgs.home-manager

      # just: task runner / discoverability layer (`just --list` shows all commands)
      just

      # base is what any machine wants; shell-tools is the interactive
      # comfort layer. These have genuine bootstrap/scripting/ops value
      # independent of an interactive session -- a headless `minimal`
      # machine wants them exactly as much as a daily driver does. The
      # nicer-but-optional layer (fonts, ripgrep/fd/bat/eza/lazygit/btop/
      # fastfetch, zoxide/fzf/direnv) lives in the shell-tools feature
      # instead, which `minimal` doesn't pull in.
      jq
      git-lfs
      wget
      rsync
      tree
      ncdu
      htop

      # Secrets: sops/age for the opt-in sops-nix secrets management
      # (modules/secrets-sops.nix; the age private key itself is placed
      # manually, not retrieved automatically: see that module's own
      # comment for why). rbw is independent of sops: a general password-
      # manager CLI, not part of the sops key-retrieval path.
      # rbw = maintained Rust Bitwarden CLI (official `bitwarden-cli` is marked
      # broken in the current nixpkgs pin); its agent caches unlock for scripting.
      # pinentry-tty lets rbw prompt for the master password from the terminal
      # (cross-platform; macOS has no pinentry by default).
      sops
      age
      rbw
      pinentry-tty
    ];

    activation = {
      # entryAfter writeBoundary: ~/.ssh must exist (written by HM) before ssh-keygen runs.
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
      # Idempotent: skips if the remote already exists.
      # entryAfter writeBoundary: submodule dirs must be cloned before we can add remotes.
      # user.submodules = { claude = "git@github.com:you/private-claude.git"; };
      submoduleOverrides = lib.hm.dag.entryAfter ["writeBoundary"] (
        let
          submodules = user.submodules or {};
          git = "${pkgs.git}/bin/git";
          mkOverride = name: url: ''
            _sm_dir="$HOME/.nix-config/config/${name}"
            if [ -e "$_sm_dir/.git" ]; then
              _has_private=$(${git} -C "$_sm_dir" remote get-url private 2>/dev/null && echo yes || echo no)
              if [ "$_has_private" = "no" ]; then
                $DRY_RUN_CMD ${git} -C "$_sm_dir" remote add private "${url}"
                if GIT_SSH="${pkgs.openssh}/bin/ssh" $DRY_RUN_CMD ${git} -C "$_sm_dir" fetch private; then
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

    # stateVersion gates Home Manager's migration behavior (default file
    # locations/formats), not a version pin: bumping it can require manual
    # data migration on a machine that has already applied an older value.
    # Before switching on an existing machine, diff `home-manager news`
    # output and check for anything relevant to programs enabled here (git,
    # zsh, tmux, vim, ssh).
    stateVersion = "25.05";
  };

  # lib.mkMerge, not `//`: the compat helpers below return *nested* fragments
  # (programs.git.settings.user, programs.git.delta) that overlap each other's
  # parent attributes. `//` is a shallow merge, so it would silently drop the
  # losing side of any such overlap rather than combining them. mkMerge defers
  # to the module system's own recursive merge, which also keeps mkForce
  # priorities working (work.nix overrides the git identity that way).
  programs = lib.mkMerge [
    {
      # ── Shells ────────────────────────────────────────────────────────────────

      zsh = {
        enable = true;
        enableCompletion = true;
        # Rebuild the completion dump (which audits every fpath dir: the
        # dominant zsh-startup cost) at most once a day; otherwise reuse the
        # cached dump and skip the audit with -C. This is the big startup win.
        completionInit = ''
          autoload -Uz compinit
          # Full compinit (rebuild the dump + audit every fpath dir) when the
          # cached dump is missing OR older than a day; otherwise load it and
          # skip the audit (-C). The glob alone only catches "exists and
          # stale": an (N…) qualifier against a nonexistent file matches
          # nothing, which would otherwise silently take the fast, unaudited
          # path on every machine's very first shell startup.
          _zdumpfile="''${ZDOTDIR:-$HOME}/.zcompdump"
          _zdump=($_zdumpfile(N.mh+24))
          if [[ ! -f $_zdumpfile ]] || (( $#_zdump )); then
            compinit
          else
            compinit -C
          fi
          unset _zdumpfile _zdump
        '';
        # envExtra → .zshenv (sourced first, before .zshrc). Nix must be on
        # PATH before any other module's tool-integration init hooks run.
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

      # fish is available alongside zsh/bash; fzf/zoxide fish integration is
      # wired in the shell-tools feature, not here. An interactive fish
      # inherits PATH and secrets from the launching shell, so tools resolve
      #: this repo doesn't set fish as anyone's login shell, so nix-profile
      # sourcing / secrets-env parsing in fish's own dialect isn't wired here
      # (fish can't `source` the POSIX ~/.config/secrets/env directly; zsh/
      # bash always initialize first).
      fish.enable = true;

      # ── Prompt ────────────────────────────────────────────────────────────────
      # caret: zero-subprocess prompt (directory + git branch + exit-status
      # arrow only: no hostname, language versions, AWS region, or command
      # duration; that's caret's own scope boundary, not this config's).
      # Replaces starship, which forks/execs per render and parses a TOML
      # config even for modules that render nothing.
      caret = {
        enable = true;
        truncationLength = 3;
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
      # credential.helper is NOT set here: gui-darwin/gui-linux own that

      # Blocks are written in upstream ssh_config(5) directive names, which is
      # what HM master's `programs.ssh.settings` takes; hm-compat converts them
      # back to 25.05's typed `matchBlocks` shape on the pinned darwin pair.
      # Booleans render as yes/no under both.
      ssh =
        {
          enable = true;
          includes = ["~/.ssh/config.d/*"]; # work.nix writes stubs here
        }
        // compat.sshBlocks {
          "*" =
            {
              IdentityFile = "~/.ssh/${user.sshKey}";
              AddKeysToAgent = "yes";
            }
            // lib.optionalAttrs pkgs.stdenv.isDarwin {
              UseKeychain = "yes";
            };
          "github.com" = {
            User = "git";
            IdentitiesOnly = true;
          };
        }
        // compat.sshDefaultConfigOff;

      # ── Git ───────────────────────────────────────────────────────────────────

      git = lib.mkMerge [
        {
          enable = true;

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
        }
        (compat.gitIdentity {inherit (user) name email;})
        (compat.gitConfig {
          init.defaultBranch = "main";
          pull.rebase = false;
          push.default = "simple";
          push.autoSetupRemote = true;
          core.autocrlf = "input";
          # diff.tool and merge.tool are set by gui-darwin/gui-linux (where `code` is available)
          # credential.helper intentionally absent: set by gui-darwin or gui-linux
        })
      ];
    }
    # delta's `enable` pulls in the delta package itself (see the home.packages
    # comment above) and wires it in as git's actual diff pager. Which option
    # path that lives under moved in HM master: hm-compat picks the right one,
    # and on the pinned pair it lands under programs.git, which is exactly why
    # this is a mkMerge element rather than a `//` operand.
    (compat.deltaConfig {
      navigate = true;
      line-numbers = true;
    })
  ];
}
