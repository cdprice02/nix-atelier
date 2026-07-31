{
  lib,
  pkgs,
  user,
  context,
  ...
}: let
  # Home Manager runs activation with a hermetic PATH -- bash, coreutils,
  # diffutils, findutils, gettext, gnugrep, gnused, jq, ncurses and nix, and
  # nothing else. Neither /usr/bin nor any of env.nix's writable bin dirs are on
  # it. Two consequences this helper exists to handle:
  #
  #   1. `curl` must be an absolute store path. A bare `curl` is not found even
  #      on macOS, where /usr/bin/curl exists, and activation dies with exit
  #      127. Every other activation script in this repo already uses store
  #      paths (${pkgs.openssh}/bin/ssh-keygen, ${pkgs.git}/bin/git).
  #   2. `command -v <binary>` cannot be the "already installed?" guard, because
  #      the install target (~/.local/bin) is never on that PATH -- the check
  #      would fail every time and reinstall on every single switch. Test the
  #      install path directly instead.
  #
  # A failed download warns rather than aborting: a transient network problem
  # should not take down an otherwise-complete `switch`, the same way
  # work.nix's corporate-cert step warns when its PEM is missing.
  mkNativeInstaller = {
    binary,
    url,
  }: ''
    if [ -z "$DRY_RUN_CMD" ] && [ ! -x "$HOME/.local/bin/${binary}" ]; then
      echo "installing ${binary} via its native installer..."
      if [ "$(id -u)" -eq 0 ]; then
        # darwin-rebuild switch runs as root; delegate to the target user so
        # the installer never creates root-owned files in $HOME.
        /usr/bin/sudo -u ${user.username} env HOME="$HOME" \
          ${pkgs.bash}/bin/bash -c '${pkgs.curl}/bin/curl -fsSL ${url} | ${pkgs.bash}/bin/bash' \
          || echo "WARNING: ${binary} install failed (network?); rerun switch to retry."
      else
        ${pkgs.curl}/bin/curl -fsSL ${url} | ${pkgs.bash}/bin/bash \
          || echo "WARNING: ${binary} install failed (network?); rerun switch to retry."
      fi
    fi
  '';
in {
  home.activation =
    {
      # claude-code via its own native installer, not npm or nixpkgs: it ships
      # multiple releases a week and self-updates in place (`claude update`) —
      # Nix's rebuild-to-update cycle can't keep pace, and nixpkgs's packaged
      # version lags too. Installs to ~/.local/bin/claude, already on PATH via
      # env.nix's XDG_BIN_HOME.
      claudeCode = lib.hm.dag.entryAfter ["writeBoundary"] (
        mkNativeInstaller {
          binary = "claude";
          url = "https://claude.ai/install.sh";
        }
      );
    }
    // lib.optionalAttrs (context == "work") (
      {
        # kiro-cli (AWS's agentic CLI) — same native-installer rationale as
        # claude-code above; not in nixpkgs at all (confirmed). Work-only:
        # gated inside this feature (dev tier, so uv is present for its MCP
        # servers) rather than in work.nix, which also covers work-minimal/
        # work-server — neither has uv.
        kiroCli = lib.hm.dag.entryAfter ["writeBoundary"] (
          mkNativeInstaller {
            binary = "kiro-cli";
            url = "https://cli.kiro.dev/install";
          }
        );
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
