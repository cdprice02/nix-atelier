{
  config,
  lib,
  pkgs,
  user,
  ...
}:
let
  # Home Manager runs activation with a hermetic PATH -- bash, coreutils,
  # diffutils, findutils, gettext, gnugrep, gnused, jq, ncurses and nix, and
  # nothing else. Neither /usr/bin nor any of env.nix's writable bin dirs are on
  # it. Three consequences this file has to handle:
  #
  #   1. `curl` must be an absolute store path. A bare `curl` is not found even
  #      on macOS, where /usr/bin/curl exists, and activation dies with exit
  #      127. Every other activation script in this repo already uses store
  #      paths (${pkgs.openssh}/bin/ssh-keygen, ${pkgs.git}/bin/git).
  #   2. `command -v <binary>` cannot be the "already installed?" guard, because
  #      the install target (~/.local/bin) is never on that PATH -- the check
  #      would fail every time and reinstall on every single switch. Test the
  #      install path directly instead.
  #   3. Fixing the invocation alone isn't enough: the downloaded script below
  #      runs as a child process and inherits this same PATH, so it fails its
  #      own dependency probe ("Either curl or wget is required but neither is
  #      installed") unless the child is launched with a usable PATH too, not
  #      just an absolute curl.
  #
  # PATH handed to the vendor installer. Nix-provided tools come first so the
  # download itself is deterministic; the system paths follow because these
  # scripts reasonably expect a normal environment. claude's installer needs
  # `shasum -a 256` on darwin to verify its checksum, and shasum is a Perl
  # script (/usr/bin/shasum on macOS) -- it is NOT in coreutils, whose
  # sha256sum the installer only uses on Linux. Pulling perl into every
  # dev-tier closure just for that would be a poor trade, and this hook is
  # deliberately running an unsandboxed vendor script anyway.
  installerPath = "${
    lib.makeBinPath [
      pkgs.curl
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
    ]
  }:/usr/bin:/bin";

  # pipefail matters here specifically: without it `curl ... | bash` reports
  # only bash's status, so a failed download piping nothing into a shell that
  # exits 0 would be indistinguishable from a successful install.
  #
  # A failure warns rather than aborting, so a transient network problem
  # cannot take down an otherwise-complete switch.
  mkNativeInstaller =
    {
      binary,
      url,
    }:
    let
      run = "set -o pipefail; ${pkgs.curl}/bin/curl -fsSL ${url} | ${pkgs.bash}/bin/bash";
      warn = "echo \"WARNING: ${binary} install failed; rerun 'just switch' to retry.\"";
    in
    ''
      if [ -z "$DRY_RUN_CMD" ] && [ ! -x "$HOME/.local/bin/${binary}" ]; then
        echo "installing ${binary} via its native installer..."
        if [ "$(id -u)" -eq 0 ]; then
          # darwin-rebuild switch runs as root; delegate to the target user so
          # the installer never creates root-owned files in $HOME.
          /usr/bin/sudo -u ${user.username} \
            env HOME="$HOME" PATH="${installerPath}" \
            ${pkgs.bash}/bin/bash -c '${run}' || ${warn}
        else
          env PATH="${installerPath}" \
            ${pkgs.bash}/bin/bash -c '${run}' || ${warn}
        fi
      fi
    '';
  # Generic counterpart to claudeCode below, for any other native-installer
  # CLI a machine's user.nix declares. The framework has no opinion on what
  # these are -- unlike claude-code, there's no default here at all. Keyed by
  # binary name so two entries can't collide silently.
  nativeInstallerMods = lib.listToAttrs (
    map (spec: {
      name = "nativeInstaller-${spec.binary}";
      value = lib.hm.dag.entryAfter [ "writeBoundary" ] (mkNativeInstaller {
        inherit (spec) binary url;
      });
    }) (user.nativeInstallers or [ ])
  );

  # Generic counterpart to the old hardcoded ~/.kiro clone: real,
  # independently-pushed git clones of private config repos, keyed by the
  # path under $HOME to clone into. Not submodules of this (public) repo --
  # a private submodule would break every CI job's `submodules: recursive`
  # checkout (no credentials for a private repo there), and the URL would
  # otherwise have to live in this public repo's .gitmodules. Guarded like
  # the SSH-key activation hook in base.nix: write-once, never re-clones
  # over local changes.
  configRepoMods = lib.mapAttrs' (
    path: url:
    lib.nameValuePair "configRepo-${path}" (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ ! -d "$HOME/${path}/.git" ]; then
          $DRY_RUN_CMD ${pkgs.git}/bin/git clone "${url}" "$HOME/${path}"
        fi
      ''
    )
  ) (user.configRepos or { });
in
{
  # Submodule under config/ symlinked into HOME so tools find it at the
  # expected path. mkOutOfStoreSymlink keeps it live-editable (not copied
  # into the Nix store), which is required for a git-managed tool config.
  home.file.".claude" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.nix-atelier/config/claude";
  };

  home.activation = {
    # claude-code via its own native installer, not npm or nixpkgs: it ships
    # multiple releases a week and self-updates in place (`claude update`);
    # Nix's rebuild-to-update cycle can't keep pace, and nixpkgs's packaged
    # version lags too. Installs to ~/.local/bin/claude, already on PATH via
    # env.nix's XDG_BIN_HOME. Unlike nativeInstallerMods below, this one is
    # not user-declared: every machine with this feature gets Claude Code,
    # the same way any other feature's packages aren't opt-in per-item.
    #
    # entryAfter ["linkGeneration"], not "writeBoundary": on a genuinely
    # fresh machine (no prior ~/.local/bin/claude), the installer's own
    # first-run setup creates ~/.claude as a real directory for its default
    # config. home.file.".claude" above wants that same path as its
    # symlink target, but linkGeneration (home-manager's own built-in phase
    # that materializes home.file) only runs after every custom
    # writeBoundary-anchored activation script -- so at "writeBoundary"
    # priority the installer would always win the race and leave `ln`
    # nothing to do but fail with "cannot overwrite directory". Anchoring
    # after linkGeneration instead means the symlink exists first, so the
    # installer just writes its defaults straight into the already-live
    # config/claude submodule, matching this repo's actual steady-state
    # (Claude Code's runtime state living inside a git-tracked submodule).
    # Found by bootstrap-smoke-test's own fresh-container run, not assumed.
    claudeCode = lib.hm.dag.entryAfter [ "linkGeneration" ] (mkNativeInstaller {
      binary = "claude";
      url = "https://claude.ai/install.sh";
    });
  }
  // nativeInstallerMods
  // configRepoMods;
}
