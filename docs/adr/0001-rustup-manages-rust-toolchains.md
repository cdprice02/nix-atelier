# rustup manages Rust toolchains, outside the Nix store

`lang-rust` installs rustup from nixpkgs and lets it own the toolchains in
`~/.rustup`, instead of building one toolchain into the store with
rust-overlay. Only rustup's proxies honor a project's `rust-toolchain.toml`
and keep stable, beta, and nightly installed side by side, without asking
every project to carry its own `flake.nix` and direnv setup. The cost is
that toolchains are no longer reproducible from this flake: each project's
own pin, and its CI, are what make a build reproducible.

## Considered Options

- **rust-overlay, one floating nightly** (the previous setup): ignores
  toolchain files, allows one channel per machine, and its churn was a
  recurring source of broken switches.
- **Per-project dev shells** (`fromRustupToolchainFile`, or fenix):
  reproducible, but every project needs Nix wiring before `cargo` works.
- **fenix in place of rust-overlay**: changes where the churn comes from,
  not any of the above.

## Consequences

- Activation installs missing channels and never updates them, so a
  switch works offline; `rustup update` is a deliberate, separate step.
- `rust-analyzer` is a wrapper around the default toolchain's component
  rather than nixpkgs' build, which on x86_64-darwin's pinned release is
  too old for current toolchains.
- `pkgs.rust-bin` is gone from the package set consumers receive.
