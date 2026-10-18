{
  config,
  lib,
  pkgs,
  user,
  ...
}:
let
  inherit (config.atelier.rust) toolchains defaultToolchain;
  rustupBin = "${pkgs.rustup}/bin/rustup";
  host = pkgs.stdenv.hostPlatform.rust.rustcTarget;
  components = [
    "clippy"
    "rustfmt"
    "rust-src"
    "rust-analyzer"
  ];

  # Outranks rustup's own rust-analyzer proxy, which resolves through the
  # project's pinned toolchain and fails when that pin omits the component.
  # This one always runs the default toolchain's analyzer, which reads std
  # from whichever toolchain the project uses. Exec'd by path, not via
  # `rustup run`: that exports RUSTUP_TOOLCHAIN, which would override the
  # project's pin for every cargo and rustc the analyzer spawns. nixpkgs'
  # rust-analyzer is not used: x86_64-darwin's pinned release carries a build
  # too old for current toolchains.
  rustAnalyzer = pkgs.writeShellScriptBin "rust-analyzer" ''
    exec "$(${rustupBin} which --toolchain "${defaultToolchain}" rust-analyzer)" "$@"
  '';
  targets =
    if pkgs.stdenv.isDarwin then
      [
        "x86_64-apple-darwin"
        "aarch64-apple-darwin"
      ]
    else
      [
        "x86_64-unknown-linux-gnu"
        "aarch64-unknown-linux-gnu"
      ];
  # Quoted by hand rather than with lib.escapeShellArgs, whose output for
  # safe words differs between the two nixpkgs pins.
  shellWords = lib.concatMapStringsSep " " (w: "\"${w}\"");
  warn = what: "echo \"WARNING: rustup ${what} failed; rerun 'just switch' to retry.\"";
in
{
  # Toolchains live in ~/.rustup, outside the store, so rustup's proxies can
  # honor a project's rust-toolchain.toml and several channels can sit side
  # by side. See docs/adr/0001-rustup-manages-rust-toolchains.md.

  assertions = [
    {
      assertion = builtins.elem defaultToolchain toolchains;
      message = "atelier.rust.defaultToolchain (${defaultToolchain}) must be one of atelier.rust.toolchains.";
    }
  ];

  home.packages = with pkgs; [
    rustup
    (lib.hiPrio rustAnalyzer)

    # Cargo tools
    cargo-edit
    cargo-expand
    cargo-audit
    cargo-nextest
    bacon
    samply
    watchexec
    cargo-seek
    cargo-generate
    cargo-shear
  ];

  # Install-if-missing, never update: a switch must not depend on the network
  # or pull every channel each time. Components and targets are re-added to a
  # toolchain that already exists, a no-op once they are present. Failures
  # warn rather than abort, like mkNativeInstaller.
  home.activation.rustupToolchains = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _rustup() {
      if [ "$(id -u)" -eq 0 ]; then
        # darwin-rebuild switch runs as root; ~/.rustup must stay user-owned.
        /usr/bin/sudo -u ${user.username} env HOME="$HOME" ${rustupBin} "$@"
      else
        ${rustupBin} "$@"
      fi
    }
    for _tc in ${shellWords toolchains}; do
      if [ ! -d "$HOME/.rustup/toolchains/$_tc-${host}" ]; then
        echo "installing the Rust $_tc toolchain via rustup..."
        $DRY_RUN_CMD _rustup toolchain install "$_tc" --profile minimal \
          --component ${lib.concatStringsSep "," components} \
          --target ${lib.concatStringsSep "," targets} \
          || ${warn "toolchain install $_tc"}
      else
        $DRY_RUN_CMD _rustup component add --toolchain "$_tc" ${shellWords components} \
          >/dev/null 2>&1 || ${warn "component add for $_tc"}
        $DRY_RUN_CMD _rustup target add --toolchain "$_tc" ${shellWords targets} \
          >/dev/null 2>&1 || ${warn "target add for $_tc"}
      fi
    done
    $DRY_RUN_CMD _rustup default "${defaultToolchain}" >/dev/null \
      || ${warn "default ${defaultToolchain}"}
  '';
}
