{ pkgs, ... }:
{
  # rust-analyzer discovers its sysroot via `rustc --print sysroot`, which
  # resolves to the single nightly toolchain below, and rust-src lives
  # inside that sysroot. Sysroot discovery finds it on its own; no
  # RUST_SRC_PATH or per-editor sysrootSrc override is needed. That was
  # only true under the stable+nightly split this module used before,
  # where sysroot discovery resolved to the stable toolchain and missed
  # the nightly-only rust-src entirely.

  home.packages = with pkgs; [
    # Rust: single nightly toolchain is the daily driver, carrying rustc,
    # cargo, clippy, rustfmt, rust-analyzer, and rust-src all from the same
    # build. One toolchain means nothing to reconcile between what's linted
    # and what's shipped (previously clippy ran on stable while rustfmt/
    # rust-analyzer ran on nightly; now everything comes from the same
    # nightly date, so there's no split to keep in sync).
    #
    # Nightly here is deliberately floating, not pinned to a specific date
    # like this repo's other inputs (nixpkgs/home-manager): those are pinned
    # together because they must stay release-paired, but nightly rust has
    # no such pairing constraint, and floating is the point, always the
    # newest available build.
    #
    # Extensions are passed at .override time (not just .minimal alone):
    # some nightly dates are missing rust-analyzer/rustfmt/rust-src for a
    # given platform, and requesting all of them up front is what makes
    # selectLatestNightlyWith correctly reject that date and fall back to an
    # earlier one that has everything.
    (rust-bin.selectLatestNightlyWith (
      t:
      t.minimal.override {
        extensions = [
          "clippy"
          "rustfmt"
          "rust-analyzer"
          "rust-src"
        ];
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
      }
    ))

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
}
