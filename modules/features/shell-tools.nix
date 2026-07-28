{
  pkgs,
  lib,
  ...
}: let
  # Capture a tool's shell init once at build time so the shell sources a
  # static file instead of spawning the tool on every startup. Store-path
  # interpolation (not builtins.readFile) means no import-from-derivation, so
  # cross-platform eval keeps working; the capture only builds when the config
  # is realized, on its own system. Deterministic inits only (zoxide/fzf/direnv
  # emit the same script every run). fnm is excluded — its `env` output embeds
  # a per-session multishell dir, so it must run per shell (see lang-node.nix).
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
  home.packages = with pkgs; [
    # Fonts — terminal rendering, not needed on a headless box
    fira-code
    nerd-fonts.fira-code

    # CLI essentials — nicer/faster alternatives to what's already available
    # (grep/find/cat/ls/htop), not new capability
    ripgrep
    fd
    bat
    eza
    lazygit
    btop
    fastfetch
  ];

  programs = {
    # zsh/bash integration is done via static build-time captures (toolInit
    # above) instead of these modules' per-startup `eval`. fish keeps HM's
    # native runtime integration.
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
    # file), not atuin. Ctrl-R = history, Ctrl-T = files, Alt-C = cd.
    fzf = {
      enable = true;
      enableZshIntegration = false;
      enableBashIntegration = false;
      enableFishIntegration = true;
    };

    # Static tool init (see mkInit) — replaces per-startup
    # `eval "$(zoxide/fzf/direnv init)"` subprocesses.
    zsh.initContent = lib.mkAfter (toolInit "zsh" "--zsh");
    bash.initExtra = lib.mkAfter (toolInit "bash" "--bash");
  };
}
