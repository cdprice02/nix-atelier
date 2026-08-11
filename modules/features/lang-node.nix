{
  pkgs,
  lib,
  ...
}:
{
  home.packages = with pkgs; [
    # Node ecosystem
    nodejs
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
