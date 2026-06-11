{ config, pkgs, lib, system, user, ... }:

let
  # QMK is pinned on x86_64 to avoid build failures on unstable
  qmkPackage =
    if lib.strings.hasPrefix "x86_64" system then
      let
        pinnedPkgs = import (builtins.fetchTarball {
          url    = "https://github.com/NixOS/nixpkgs/archive/0c408a087b4751c887e463e3848512c12017be25.tar.gz";
          sha256 = "049l2w7sngxb354kkrvaigzkkiz5073y7s176xdvqgm4gyzp05dw";
        }) { inherit system; };
      in pinnedPkgs.qmk
    else pkgs.qmk;
in
{
  home.packages = with pkgs; [
    # Rust — stable + nightly both preinstalled via rust-overlay so switching is instant.
    # Switch with: rustup default nightly / rustup default stable / cargo +nightly
    # rust-analyzer lives only in nightly to avoid the proc-macro-srv path conflict.
    (rust-bin.stable.latest.default.override {
      extensions = [ "rust-src" "rustfmt" "clippy" ];
      targets    = if pkgs.stdenv.isDarwin
        then [ "x86_64-apple-darwin"      "aarch64-apple-darwin"      ]
        else [ "x86_64-unknown-linux-gnu"  "aarch64-unknown-linux-gnu" ];
    })
    # Nightly rust-analyzer only — minimal install to avoid path conflicts with stable
    rust-bin.nightly.latest.rust-analyzer

    # Cargo tools
    cargo-edit
    cargo-watch
    cargo-expand
    cargo-audit
    samply

    # Node ecosystem
    nodejs
    fnm

    # Python ecosystem
    python3
    uv
    bun
    python3Packages.jupyterlab
    python3Packages.ipython

    # AWS
    awscli2
    aws-vault

    # Dev tools
    gh
    tmux
    qmkPackage
  ];

  # Claude Code — not yet in nixpkgs; installed globally via npm
  # Requires npm on PATH — run manually if activation skips it:
  #   npm install -g @anthropic-ai/claude-code
  home.activation.claudeCode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -z "$DRY_RUN_CMD" ] && ! command -v claude &>/dev/null && command -v npm &>/dev/null; then
      mkdir -p "$HOME/.npm-global/bin"
      export PATH="$HOME/.nix-profile/bin:$HOME/.npm-global/bin:$PATH"
      npm install -g @anthropic-ai/claude-code
    fi
  '';

  # fnm shell init — appended after base shell config
  programs.zsh.initContent = lib.mkAfter ''
    eval "$(fnm env --use-on-cd)"
  '';

  programs.bash.initExtra = lib.mkAfter ''
    eval "$(fnm env --use-on-cd)"
  '';

  programs.tmux = {
    enable       = true;
    keyMode      = "vi";
    mouse        = true;
    terminal     = "screen-256color";
    historyLimit = 10000;
    extraConfig  = ''
      set -g status-style bg=black,fg=white
      set -g status-left  "#[fg=green]#S "
      set -g status-right "#[fg=yellow]%H:%M"
      bind | split-window -h
      bind - split-window -v
    '';
  };
}
