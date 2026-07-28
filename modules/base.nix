{
  config,
  options,
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

  # Capture a tool's shell init once at build time so the shell sources a
  # static file instead of spawning the tool on every startup. Store-path
  # interpolation (not builtins.readFile) means no import-from-derivation, so
  # cross-platform eval keeps working; the capture only builds when the config
  # is realized, on its own system. Deterministic inits only (zoxide/fzf/direnv
  # emit the same script every run). fnm is excluded — its `env` output embeds
  # a per-session multishell dir, so it must run per shell (see dev.nix).
  mkInit = name: cmd: pkgs.runCommand "hm-shell-init-${name}" {} "${cmd} > $out";
  toolInit = shell: fzfFlag: let
    src = tool: cmd: "source ${mkInit "${tool}-${shell}" cmd}";
    fzfSrc = src "fzf" "${pkgs.fzf}/bin/fzf ${fzfFlag}";
    # fzf's zsh init toggles the `zle` option; only source it when zle is
    # available, matching home-manager's own guard — otherwise zsh warns
    # "can't change option: zle" in interactive-but-non-zle contexts.
    fzf =
      if shell == "zsh"
      then ''
        if [[ $options[zle] = on ]]; then
          ${fzfSrc}
        fi
      ''
      else fzfSrc;
  in ''
    ${src "zoxide" "${pkgs.zoxide}/bin/zoxide init ${shell}"}
    ${src "direnv" "${pkgs.direnv}/bin/direnv hook ${shell}"}
    ${fzf}
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
      # EDITOR is set by programs.vim.defaultEditor below, not here — avoid
      # declaring it twice.
      CLAUDE_PROFILE = context;
    };

    # Runtime-tool PATH and writable install prefixes (cargo/npm/uv/bun/pixi)
    # live in modules/env.nix, imported alongside this module for every profile.

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
      # delta provided by programs.git.delta.enable below, not listed here
      lazygit
      git-lfs
      wget
      btop
      # neofetch is archived/unmaintained upstream (removed from nixpkgs);
      # fastfetch is its actively maintained, faster replacement.
      fastfetch

      # Secrets — SOPS-encrypted secrets in git (age recipients), master key
      # retrieved from Bitwarden at deploy time. See homelab deploy/secrets/.
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

    # stateVersion gates Home Manager's migration behavior (default file
    # locations/formats), not a version pin — bumping it can require manual
    # data migration on a machine that has already applied an older value.
    # 23.11 was stale against nixpkgs-unstable; bumped to the current release
    # nearest this repo's last update. Before switching on an existing
    # machine, diff `home-manager news` output and check for anything
    # relevant to programs enabled here (git, zsh, tmux, vim, ssh).
    stateVersion = "25.05";
  };

  programs =
    {
      # ── Shells ────────────────────────────────────────────────────────────────

      zsh = {
        enable = true;
        enableCompletion = true;
        # Rebuild the completion dump (which audits every fpath dir — the
        # dominant zsh-startup cost) at most once a day; otherwise reuse the
        # cached dump and skip the audit with -C. This is the big startup win.
        completionInit = ''
          autoload -Uz compinit
          # Full compinit (rebuild the dump + audit every fpath dir) only when
          # the cached dump is missing or older than a day; otherwise load it
          # and skip the audit (-C). Uses array-glob filename generation — a
          # bare `[[ -n glob ]]` performs none, so the age test would always be
          # true — with a plain (N…) qualifier that needs no EXTENDED_GLOB.
          _zdump=(''${ZDOTDIR:-$HOME}/.zcompdump(N.mh+24))
          if (( $#_zdump )); then
            compinit
          else
            compinit -C
          fi
          unset _zdump
        '';
        # envExtra → .zshenv (sourced first, before .zshrc). Nix must be on PATH
        # before tool integrations (fnm, zoxide) evaluate their init hooks.
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
          ''
          # Static tool init (see mkInit) — replaces per-startup
          # `eval "$(zoxide/fzf/direnv init)"` subprocesses.
          + toolInit "zsh" "--zsh";
      };

      bash = {
        enable = true;
        enableCompletion = true;
        profileExtra = nixProfileInit;
        # Static tool init (see mkInit) replaces per-startup eval subprocesses.
        initExtra = envLocalInit + toolInit "bash" "--bash";
      };

      # fish is available alongside zsh/bash with tool integrations wired
      # (fzf/zoxide below). An interactive fish inherits PATH and secrets from
      # the launching shell, so tools resolve — this repo doesn't set fish as
      # anyone's login shell, so nix-profile sourcing / secrets-env parsing in
      # fish's own dialect isn't wired here (fish can't `source` the POSIX
      # ~/.config/secrets/env directly; zsh/bash always initialize first).
      fish.enable = true;

      # ── Prompt ────────────────────────────────────────────────────────────────
      # caret: zero-subprocess prompt (directory + git branch + exit-status
      # arrow only — no hostname, language versions, AWS region, or command
      # duration; that's caret's own scope boundary, not this config's).
      # Replaces starship, which forks/execs per render and parses a TOML
      # config even for modules that render nothing.
      caret = {
        enable = true;
        truncationLength = 3;
      };

      # ── Shell tools ───────────────────────────────────────────────────────────

      # zsh/bash integration is done via static build-time captures (see
      # toolInit / mkInit) instead of these modules' per-startup `eval`, so the
      # zsh/bash integrations are disabled here. fish keeps HM's runtime
      # (`eval`-based) integration — fish is a secondary, not-login shell here
      # (see the fish.enable comment above), so its startup cost isn't on the
      # optimized path.
      direnv = {
        enable = true;
        nix-direnv.enable = true;
        enableZshIntegration = false;
        enableBashIntegration = false;
      };

      zoxide = {
        enable = true;
        enableZshIntegration = false;
        enableBashIntegration = false;
        enableFishIntegration = true;
      };

      # History search is fzf's native Ctrl-R widget (over the shell history
      # file), not atuin: no per-command recording hook, no daemon, and fzf
      # only spawns when a binding is pressed. Ctrl-R = history, Ctrl-T =
      # files, Alt-C = cd. (atuin was dropped here — it added a startup
      # subprocess + precmd SQLite write for a richer/synced DB we don't need.)
      fzf = {
        enable = true;
        enableZshIntegration = false;
        enableBashIntegration = false;
        enableFishIntegration = true;
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

      ssh =
        {
          enable = true;
          includes = ["~/.ssh/config.d/*"]; # work.nix writes stubs here
          matchBlocks = {
            "*" = {
              identityFile = "~/.ssh/${user.sshKey}";
              # AddKeysToAgent via extraOptions (a raw ssh directive) rather than
              # the typed `addKeysToAgent` option: newer home-manager exposes it
              # as a per-host match-block option, but HM 25.05 (the darwin pin)
              # only has it as a global `programs.ssh.addKeysToAgent`.
              # extraOptions is freeform and accepted by both, keeping this match
              # block valid across HM versions.
              extraOptions =
                {
                  AddKeysToAgent = "yes";
                }
                // lib.optionalAttrs pkgs.stdenv.isDarwin {
                  UseKeychain = "yes";
                };
            };
            "github.com" = {
              user = "git";
              identitiesOnly = true;
            };
          };
        }
        # enableDefaultConfig only exists in newer home-manager (Linux profiles
        # track HM master); darwin is pinned to HM release-25.05, which predates
        # it. On newer HM, disable the injected default `*` match block so the
        # explicit one above is authoritative; on 25.05 there is no injected
        # default, so the option is simply absent. Guard on the option's
        # existence to keep base.nix valid against both HM versions.
        // lib.optionalAttrs (options.programs.ssh ? enableDefaultConfig) {
          enableDefaultConfig = false;
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

        # enable pulls in the delta package itself (see the home.packages comment
        # above) and wires it in as git's actual diff pager, previously just
        # installed with nothing pointing at it.
        delta = {
          enable = true;
          options = {
            navigate = true;
            line-numbers = true;
          };
        };
      };
    }
    # Newer HM auto-enables delta's git integration at a low priority and warns
    # that the implicit behavior is deprecated. Setting it explicitly silences
    # the warning and pins the behavior this config wants. HM 25.05 has no
    # programs.delta module at all, so guard on the option's existence — same
    # pattern as programs.ssh.enableDefaultConfig above.
    // lib.optionalAttrs (options.programs ? delta) {
      delta.enableGitIntegration = true;
    };
}
