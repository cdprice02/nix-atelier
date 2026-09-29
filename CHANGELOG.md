# Changelog

Short version history. The full story for each release, with the actual
reasoning behind each change, lives in its
[GitHub Release](https://github.com/cdprice02/nix-atelier/releases) notes;
this file exists so the version list itself, and what each one meant, is
somewhere you don't have to leave the repo to find.

See [CONTRIBUTING.md](CONTRIBUTING.md#releases-and-versioning) for what
actually constitutes a release here, and
[docs/migrating-to-v3.md](docs/migrating-to-v3.md) if you're on v2 and
upgrading.

## Unreleased -- neovim

Neovim becomes the daily-driver editor: a new `neovim` feature (in `full`)
installs it with every language server, formatter and build tool its config
needs, and links the new `config/nvim` submodule
([cdprice02/nvim-config](https://github.com/cdprice02/nvim-config), modeled
on ThePrimeagen's) to `~/.config/nvim`, live-editable like `config/claude`.
`EDITOR`/`VISUAL` become `nvim` wherever the feature is on. `tmux` turns
Neovim-friendly (true color, no Esc delay, focus events, OSC 52 clipboard,
vi copy mode) and gains `tmux-sessionizer` (`prefix f`), a Claude Code split
(`prefix C`) and a lazygit popup (`prefix g`); `lang-python` adds `jupytext`.
No schema change: a consumer that doesn't want it drops `neovim` via
`features.exclude`.

## [v3.1.1](https://github.com/cdprice02/nix-atelier/releases/tag/v3.1.1) -- follow-up

2026-10-01

One real bug, found by reviewing v3.1.0 after it shipped:
`features.extraSystemModulePaths` was accepted on a `configs.home` entry
and then silently ignored (#187). A standalone Home Manager config has no
system module layer for it to extend, so a path set there went nowhere; it
is now a hard evaluation error instead. Tagged patch rather than major
despite removing a field from the schema: the field only existed on that
kind for two days, never had any effect, and any call that set it was
already not getting what it asked for.

Also: inline issue-number references are gone from code comments and docs
(#188), where they read as framework-internal history to anyone consuming
this as a flake input, and three documentation gaps v3.1.0 left behind are
closed (#189) -- `config/skills` in the repo layout, and per-config
`features` in both `docs/profiles.md` and `templates/default/flake.nix`.

## [v3.1.0](https://github.com/cdprice02/nix-atelier/releases/tag/v3.1.0) -- per-machine

2026-09-29

New capability, no breaking schema change: `configs.<kind>.<name>.features`
(#171) lets two configs in one `mkConfigs` call diverge (a laptop with k8s
access, a WSL work machine without) without splitting into separate calls
or hand re-importing a feature module. `atelier.checkoutPath` (#149) makes
the local framework checkout path configurable, so `claude`/`copilot`/
`git-tools` work for a consumer whose checkout isn't at `~/.nix-atelier`.

Rust moves to a single floating nightly toolchain (`rustc`, `cargo`,
`clippy`, `rustfmt`, `rust-analyzer`, `rust-src`, all one build), replacing
the stable+nightly split and the `RUST_SRC_PATH` workaround it needed.
`watchexec`/`cargo-seek`/`cargo-generate`/`cargo-shear` join the Rust
toolkit; `cargo-watch` drops. `config/skills`, a 4th submodule (a fork of
mattpocock/skills), adds `just link-skills` to symlink its promoted skills
in. `websocat` joins the `k8s` feature, for the parts of Home Assistant's
API that are websocket-only. `kiro-cli` invocations default to `--v3`
(#172).

Also fixed: the weekly `flake.lock` update had been silently failing for a
month (`nmt`'s input pinned a tag as a bare ref, which Nix resolves as a
branch first). A repo-wide structural and comment pass (#143) extracted
`lib/mkProfile.nix` and `lib/tool-catalog-drift.nix` out of `flake.nix`,
deleted two blocks of dead code, and trimmed the handful of comments that
turned out to be genuinely stale rather than load-bearing.

## [v3.0.1](https://github.com/cdprice02/nix-atelier/releases/tag/v3.0.1) -- patch

2026-08-19

Two fixes, no schema change: rust-analyzer can resolve `std` again
(`RUST_SRC_PATH` points it at the real `rust-src`, not the sysroot's own
copy, which never ships it), and `build-darwin` retries a transient
checkout failure instead of going red over a one-off TLS blip on the
runner.

## [v3.0.0](https://github.com/cdprice02/nix-atelier/releases/tag/v3.0.0) -- consumable

2026-08-18

The point this stopped being something you fork, and became something you
depend on: `lib.mkConfigs`, called from your own `flake.nix`, is now the
only path. `user.nix` and `--impure` are gone entirely,
`templates/default/flake.nix` (`nix flake init -t github:cdprice02/nix-atelier`)
replaces fork-and-edit, NixOS joins as a third config kind, and real
coverage (activation scripts, a real `darwin-rebuild switch` in CI,
`secrets-sops.nix`) replaces several previously-unasserted mechanisms. See
[docs/migrating-to-v3.md](docs/migrating-to-v3.md) if you're upgrading a
v1/v2 fork.

## [v2.1.0](https://github.com/cdprice02/nix-atelier/releases/tag/v2.1.0) -- proven

2026-08-11

CI stopped taking the framework's word for it and started running it: a
real activation-then-upgrade smoke test (not just a closure build), a
four-system `flake-check` matrix (darwin and aarch64-linux previously had no
nmt coverage in CI at all), every formatter/linter collapsed into one
`treefmt.nix` invocation, and `just switch` gained a diff-before-activate
preview via `nh`.

## [v2.0.0](https://github.com/cdprice02/nix-atelier/releases/tag/v2.0.0) -- extensible

2026-08-11

The point this stopped being something you fork and edit, and became
something you fork and *configure*: `extraFeatures`/`excludeFeatures`/
`extraModulePaths` as real extension points, native installers and private
config-repo clones moved from hardcoded to user-declared, and secrets moved
out of this (public) repo's own history entirely. Renamed `nix-config` ->
`nix-atelier` in this release.

## [v1.0.0](https://github.com/cdprice02/nix-atelier/releases/tag/v1.0.0) -- forkable

2026-07-31

Milestone marker, not a functional release: the point the documented
bootstrap sequence actually worked end to end, verified by a smoke test that
had never once passed before this. Four separate blockers fixed, each of
which made the guide unrunnable at the step it appeared.
