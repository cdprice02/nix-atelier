{
  lib,
  user,
  ...
}: {
  # claude-code via its own native installer, not npm or nixpkgs: it ships
  # multiple releases a week and self-updates in place (`claude update`) —
  # Nix's rebuild-to-update cycle can't keep pace, and nixpkgs's packaged
  # version lags too. Installs to ~/.local/bin/claude, already on PATH via
  # env.nix's XDG_BIN_HOME.
  home.activation.claudeCode = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ -z "$DRY_RUN_CMD" ] && ! command -v claude &>/dev/null; then
      if [ "$(id -u)" -eq 0 ]; then
        # darwin-rebuild switch runs as root; delegate to the target user so
        # the installer never creates root-owned files in $HOME.
        /usr/bin/sudo -u ${user.username} env HOME="$HOME" \
          sh -c 'curl -fsSL https://claude.ai/install.sh | bash'
      else
        curl -fsSL https://claude.ai/install.sh | bash
      fi
    fi
  '';
}
