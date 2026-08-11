{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Rust: stable toolchain is the daily-driver default. rust-analyzer and
    # rustfmt are pinned to nightly (better proc-macro/type inference;
    # unstable formatting options). rust-src travels with rust-analyzer (not
    # the stable toolchain) since stable/nightly rust-src have different
    # internal layouts and a mismatch breaks std-type resolution; rustfmt
    # has no rust-src dependency. clippy stays on stable: it lints
    # whatever's actually compiled and shipped.
    #
    # Nightly here is deliberately floating, not pinned to a specific date
    # like this repo's other inputs (nixpkgs/home-manager): those are pinned
    # together because they must stay release-paired, but nightly
    # rust-analyzer has no such pairing constraint, and floating is the
    # point, always the newest available build.
    #
    # rust-analyzer/rustfmt/rust-src are pulled from .availableComponents,
    # NOT via toolchain.minimal.override: every rust-overlay "toolchain"
    # composite (even `minimal`) unconditionally ships share/doc/rust/
    # COPYRIGHT.html, so combining a stable and a nightly toolchain in one
    # profile always collides on that path. The individual components have
    # no such shared doc path and combine cleanly.
    (rust-bin.stable.latest.minimal.override {
      extensions = [ "clippy" ];
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
    })
    (
      let
        # Validate against the actual components this bundle consumes, not
        # just `.minimal` (rustc/cargo/rust-std): some nightly dates are
        # missing rust-analyzer/rustfmt/rust-src for a given platform, and
        # `.minimal` alone evaluating successfully says nothing about those.
        # `.override` with these as extensions forces resolveComponents to
        # confirm all three exist for this date before selectLatestNightlyWith
        # accepts it, so a bad date still falls back correctly.
        nightly = rust-bin.selectLatestNightlyWith (
          t:
          t.minimal.override {
            extensions = [
              "rust-src"
              "rustfmt-preview"
              "rust-analyzer-preview"
            ];
          }
        );
      in
      # buildEnv (not symlinkJoin) with an explicit pathsToLink allowlist.
      # Two reasons this is not a plain symlinkJoin:
      #   1. The nightly components ship files that also ship in the stable
      #      toolchain and collide in home-manager's buildEnv (surfaces only
      #      on a real build, not eval): host linker tools under
      #      lib/rustlib/<host>/bin (wasm-component-ld, rust-lld, gcc-ld,
      #      rust-objcopy) and the gdb/lldb pretty-printers under
      #      lib/rustlib/etc. Restricting pathsToLink to the paths unique to
      #      this bundle (the rust-analyzer/rustfmt binaries and rust-src)
      #      structurally excludes them; the stable toolchain stays the
      #      authoritative source for everything else.
      #   2. rust-src's top-level `lib` is a symlink, which symlinkJoin
      #      cannot merge ("lib is a link instead of a directory"): the src
      #      tree silently goes missing, defeating the point of bundling it.
      #      buildEnv follows the symlink and links the src tree correctly.
      pkgs.buildEnv {
        name = "rust-analyzer-nightly-bundle";
        paths = with nightly.availableComponents; [
          rust-analyzer
          rustfmt
          rust-src
        ];
        pathsToLink = [
          "/bin"
          "/lib/rustlib/src"
        ];
      }
    )

    # Cargo tools
    cargo-edit
    cargo-watch
    cargo-expand
    cargo-audit
    cargo-nextest
    bacon
    samply
  ];
}
