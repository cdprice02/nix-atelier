{
  lib,
  pkgs,
  user,
  context,
  ...
}: {
  home.activation =
    {
      # claude-code via its own native installer, not npm or nixpkgs: it ships
      # multiple releases a week and self-updates in place (`claude update`) —
      # Nix's rebuild-to-update cycle can't keep pace, and nixpkgs's packaged
      # version lags too. Installs to ~/.local/bin/claude, already on PATH via
      # env.nix's XDG_BIN_HOME.
      claudeCode = lib.hm.dag.entryAfter ["writeBoundary"] ''
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
    // lib.optionalAttrs (context == "work") (
      {
        # kiro-cli (AWS's agentic CLI) — same native-installer rationale as
        # claude-code above; not in nixpkgs at all (confirmed). Work-only:
        # gated inside this feature (dev tier, so uv is present for its MCP
        # servers) rather than in work.nix, which also covers work-minimal/
        # work-server — neither has uv.
        kiroCli = lib.hm.dag.entryAfter ["writeBoundary"] ''
          if [ -z "$DRY_RUN_CMD" ] && ! command -v kiro-cli &>/dev/null; then
            if [ "$(id -u)" -eq 0 ]; then
              /usr/bin/sudo -u ${user.username} env HOME="$HOME" \
                sh -c 'curl -fsSL https://cli.kiro.dev/install | bash'
            else
              curl -fsSL https://cli.kiro.dev/install | bash
            fi
          fi
        '';
      }
      // lib.optionalAttrs (user.kiroRepo or null != null) {
        # ~/.kiro is a real, independently-pushed git clone of a private
        # work-config repo — not a submodule of this (public) repo. A private
        # submodule would break every CI job's `submodules: recursive`
        # checkout (no credentials for a private repo there), and the repo
        # URL would otherwise have to live in this public repo's .gitmodules.
        # Cloned directly instead, guarded like the SSH-key/corporate-cert
        # activation hooks: write-once, never re-clones over local changes.
        # user.kiroRepo (gitignored user.nix) supplies the URL.
        kiroConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
          if [ ! -d "$HOME/.kiro/.git" ]; then
            $DRY_RUN_CMD ${pkgs.git}/bin/git clone "${user.kiroRepo}" "$HOME/.kiro"
          fi
        '';
      }
    );
}
