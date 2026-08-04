# Runtime-tool PATH / writable-prefix policy.
#
# Node, Python, Rust, Bun and Pixi runtimes are Nix-managed, so their install
# prefixes point into the read-only /nix/store. Without an explicit writable
# prefix, `npm install -g`, `uv tool install`, `cargo install`, etc. try to
# write under the store and fail with EACCES. This module points each tool at a
# writable per-user directory and puts those directories on PATH.
#
# Imported universally alongside base.nix (see mkProfile in flake.nix): the
# variables and bin dirs are harmless on tiers that don't install the tool, and
# PATH policy is inherently profile-wide. Uses HM options (sessionVariables,
# sessionPath, home.file) that are identical across the home-manager versions
# this repo pins, so it is valid on both the rolling and 25.05 darwin pairs.
{config, ...}: let
  homeDir = config.home.homeDirectory;
in {
  home = {
    sessionVariables = {
      # npm: `npm install -g` writes here instead of the read-only Nix prefix.
      NPM_CONFIG_PREFIX = "${homeDir}/.npm-global";
      # uv: destination for `uv tool install` executables.
      UV_TOOL_BIN_DIR = "${homeDir}/.local/bin";
      # bun: install root; bun drops executables in $BUN_INSTALL/bin.
      BUN_INSTALL = "${homeDir}/.bun";
      # pixi: global install root; `pixi global install` links into $PIXI_HOME/bin.
      PIXI_HOME = "${homeDir}/.pixi";
      # XDG user bin dir: uv (and pipx/others) default tool installs here.
      XDG_BIN_HOME = "${homeDir}/.local/bin";
      # Refuse bare `pip install` outside a virtualenv, so pip never tries to
      # write into the read-only Nix Python prefix. Use uv or an explicit venv.
      PIP_REQUIRE_VIRTUALENV = "true";
    };

    # Writable per-user bin dirs. On standalone Linux/WSL2, these end up after
    # the Nix profile in the assembled PATH (nix.sh re-prepends itself after
    # hm-session-vars.sh runs), so Nix-provided tools shadow a same-named
    # user-installed binary there. On darwin this is inverted: nix-darwin's
    # /etc/zshenv sets PATH (including ~/.nix-profile/bin) before ~/.zshenv
    # sources hm-session-vars.sh, which then prepends these dirs onto that
    # already-populated PATH: so on darwin a user-installed binary here can
    # shadow a same-named Nix-provided one instead. Verified against this
    # machine's actual generated hm-session-vars.sh and /etc/zshenv.
    sessionPath = [
      "${homeDir}/.local/bin"
      "${homeDir}/.cargo/bin"
      "${homeDir}/.npm-global/bin"
      "${homeDir}/.bun/bin"
      "${homeDir}/.pixi/bin"
    ];

    # Declarative ~/.npmrc so the prefix also holds for npm invocations that read
    # the config file but not the environment (NPM_CONFIG_PREFIX wins when both
    # are present; this is the durable fallback). npmrc is not shell-expanded, so
    # the path must be absolute.
    #
    # This makes ~/.npmrc a read-only Nix store symlink, so anything that writes
    # to it directly (`npm login`, `npm config set --global`) fails with a
    # permission error rather than updating it. Not worked around here: doing
    # so would mean pointing NPM_CONFIG_USERCONFIG at a separate writable file,
    # which would stop npm from reading this declarative one at all. Known
    # limitation, not a silent one.
    file.".npmrc".text = ''
      prefix=${homeDir}/.npm-global
    '';
  };
}
