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
  home.sessionVariables = {
    # npm: `npm install -g` writes here instead of the read-only Nix prefix.
    # Matches the value dev.nix's claude-code activation hook already uses.
    NPM_CONFIG_PREFIX = "${homeDir}/.npm-global";
    # uv: destination for `uv tool install` executables.
    UV_TOOL_BIN_DIR = "${homeDir}/.local/bin";
    # bun: install root; bun drops executables in $BUN_INSTALL/bin.
    BUN_INSTALL = "${homeDir}/.bun";
    # pixi: global install root; `pixi global install` links into $PIXI_HOME/bin.
    PIXI_HOME = "${homeDir}/.pixi";
    # XDG user bin dir — uv (and pipx/others) default tool installs here.
    XDG_BIN_HOME = "${homeDir}/.local/bin";
    # Refuse bare `pip install` outside a virtualenv, so pip never tries to
    # write into the read-only Nix Python prefix. Use uv or an explicit venv.
    PIP_REQUIRE_VIRTUALENV = "true";
  };

  # Writable per-user bin dirs. HM appends these after the Nix profile in the
  # assembled PATH (verified on the applied generation: ~/.nix-profile/bin
  # precedes these), so Nix-provided tools still shadow a user-installed binary
  # of the same name — reproducible tools win, user-installed extras still work.
  home.sessionPath = [
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
  home.file.".npmrc".text = ''
    prefix=${homeDir}/.npm-global
  '';
}
