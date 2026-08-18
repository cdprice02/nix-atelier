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
