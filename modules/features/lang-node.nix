{
  pkgs,
  lib,
  ...
}:
{
  home.packages = with pkgs; [
    # Node ecosystem. Pinned to a major rather than the nixpkgs `nodejs`
    # alias, so a lock update can't silently move it; fnm still switches
    # per project.
    nodejs_24
    pnpm
    fnm
    bun
  ];

  # fnm shell init: appended after core shell config. fnm is excluded from
  # the static toolInit mechanism (see shell-tools.nix): its `env` output
  # embeds a per-session multishell dir, so it must run per shell.
  programs = {
    zsh.initContent = lib.mkAfter ''
      eval "$(fnm env --use-on-cd)"
    '';

    bash.initExtra = lib.mkAfter ''
      eval "$(fnm env --use-on-cd)"
    '';
  };
}
