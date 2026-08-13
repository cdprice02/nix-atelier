# Shared by claude.nix's own hardcoded claudeCode hook and machine.nix's
# user-declared atelier.nativeInstallers (#120): running an arbitrary vendor
# curl-piped install script during Home Manager activation. Extracted so
# there's one copy of the hermetic-PATH handling, not two kept in sync by
# hand.
{ pkgs, user }:
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
  inherit (pkgs) lib;
in
# pipefail matters here specifically: without it `curl ... | bash` reports
# only bash's status, so a failed download piping nothing into a shell that
# exits 0 would be indistinguishable from a successful install.
#
# A failure warns rather than aborting, so a transient network problem
# cannot take down an otherwise-complete switch.
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
''
