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

## [v4.4.0](https://github.com/cdprice02/nix-atelier/releases/tag/v4.4.0) -- waypoint

2026-10-28

tmux-sessionizer reaches places that are not a repo. A `~ (home)` entry
opens the `main` session at `$HOME` (also `prefix h`), a typed name that
matches nothing becomes a scratch session, and the new
`atelier.tmux.sshSessions` option adds one session per ssh host alias (#243).

Session autosave works again: tmux-continuum hooks `status-right`, and the
config set `status-right` after loading it, which deleted the hook. Resurrect
now also captures pane contents and restores `ssh`. The claude, gitalias and
skills submodule pointers move; flake inputs are refreshed (#242). Closes #211.

Minor: new `atelier.tmux.sshSessions` option; no schema change.

## [v4.3.0](https://github.com/cdprice02/nix-atelier/releases/tag/v4.3.0) -- stopwatch

2026-10-23

macOS has no `timeout`, and Claude Code shells out to it often. Every darwin
config now installs Homebrew `coreutils` and exposes a `timeout` command that
runs `gtimeout`, without putting GNU `gnubin` ahead of the BSD tools (#239).

Minor: new darwin-wide Homebrew formula; no schema change.

## [v4.2.1](https://github.com/cdprice02/nix-atelier/releases/tag/v4.2.1) -- ceiling

2026-10-22

The claude config defaults to `opusplan`: Opus plans, Sonnet implements.
Every subagent is capped at Sonnet whatever the parent model, by
`CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` alongside the existing
`CLAUDE_CODE_SUBAGENT_MODEL=sonnet` (#237).

Patch: no schema change; the claude submodule pointer moves.

## [v4.2.0](https://github.com/cdprice02/nix-atelier/releases/tag/v4.2.0) -- chroot

2026-10-21

Secrets activate on machines without a user systemd, such as an HPC login
node running Home Manager inside nix-user-chroot. Setting
`atelier.sops.userSystemd = false` runs the sops-nix install script
directly during activation, skips the user-service restart, and renders
secrets under `$XDG_STATE_HOME/sops-nix/secrets.d` (#235, closes #210).

Every profile gets `yq` (the Go one, for YAML, JSON and TOML) next to `jq`.
`lang-node` pins Node 24 and adds pnpm, with `PNPM_HOME` on the session
path so `pnpm add -g` works without `pnpm setup` editing rc files (#233).
The shared skills submodule picks up the Node package-manager rules (#234).

Minor: `atelier.sops.userSystemd` is a new option, defaulting to the
existing behavior; `lang-node` moves from the nixpkgs default Node to 24.

## [v4.1.1](https://github.com/cdprice02/nix-atelier/releases/tag/v4.1.1) -- glyphs

2026-10-19

Alacritty renders in FiraCode Nerd Font Mono, so file-type icons in oil
and devicons come from the configured font instead of an OS fallback. On
Linux, fontconfig is enabled: without it Alacritty couldn't find any of
the profile's fonts (#230). Alacritty also opens opaque and maximized,
with 50,000 lines of scrollback to match tmux, copy-on-select, a steady
block cursor, and the mouse hidden while typing (#228).

Every switch in the README, bootstrap guide and template goes through nh,
first applies included (#229). The template carries the private-config
example as a `work` config (#227), and the README shows nh's diff before
activating, re-recorded each release by `just demo` (#231).

Patch: no option or schema change.

## [v4.1.0](https://github.com/cdprice02/nix-atelier/releases/tag/v4.1.0) -- comma

2026-10-19

The README quickstart now works from a clean machine: a single-user Nix
install never put `nix` on PATH, so step 2 failed with
`nix: command not found` (#222).
Intel Macs are supported best-effort: they stay frozen on nixpkgs 25.05
until v5 drops them, and `docs/adr/0002` records why (#215).

Three bugs found on real machines are fixed (#212). A
`configs.<kind>.<name>` entry takes an optional `username`, for machines
whose login name differs from `identity.username` (an LDAP-backed HPC
node). A failing `ssh-keygen` warns instead of aborting the switch. Nested
login shells on Debian and SUSE get the Nix profile's bins on PATH, where
the vendor script returned early.

Nix itself moves to patched releases for the 2026-10-13 advisory: 2.34.9
from nixpkgs on Linux, NixOS and Apple Silicon (#223), and a separately
pinned 2.31.6 daemon on Intel Macs, whose 25.05 release ships 2.28.5
and gets no more updates (#215).

Two additions. An opt-in `nix-index` feature
(`features.extra = [ "nix-index" ]`) adds comma, so `, cowsay` runs a tool
without installing it, and names the package behind an unknown command;
not available on Intel Macs (#225). In a checkout of this repo,
`just audit` lists known CVEs in what the machine runs, using vulnix (#224).

CI builds aarch64-linux on native arm64 runners instead of QEMU (#214),
and the weekly `flake.lock` PR now runs every profile build and posts a
closure diff before it can merge (#221). Its first run caught a
Home Manager change that broke an internal check (#220).

Minor: `username` is a new optional field and `nix-index` a new opt-in
feature; no existing `mkConfigs` call changes behavior.

## [v4.0.2](https://github.com/cdprice02/nix-atelier/releases/tag/v4.0.2) -- sops-pair

2026-10-17

v4.0.1's single sops-nix pin fixed x86_64-darwin but broke every other
system with `atelier.sops.file` set: that commit builds with
`buildGo125Module`, which rolling nixpkgs has removed. sops-nix is now a
release pair like nixpkgs and home-manager: x86_64-darwin gets the pinned
`sops-nix-darwin` (following `nixpkgs-darwin`), every other system the
rolling `sops-nix`. A new `sops-install-secrets` check evaluates the
package on every system and builds it on x86_64-darwin, so either mismatch
now fails `flake-check`.

Patch: no option or schema change.

## [v4.0.1](https://github.com/cdprice02/nix-atelier/releases/tag/v4.0.1) -- sops

2026-10-17

v4.0.0 doesn't build on x86_64-darwin when `atelier.sops.file` is set.
The `flake.lock` update (#193) moved sops-nix past the commit that builds
`sops-install-secrets` with `buildGo125Module`; later commits use the
default `buildGoModule` and require go 1.26, but x86_64-darwin's pinned
25.05 nixpkgs ships go 1.24. sops-nix is now pinned to that last
compatible commit, until x86_64-darwin moves off 25.05. CI didn't catch it:
its profiles leave `atelier.sops.file` unset, so sops-nix stays inert and
`sops-install-secrets` is never built there.

Patch: no option or schema change.

## [v4.0.0](https://github.com/cdprice02/nix-atelier/releases/tag/v4.0.0) -- toolchains

2026-10-17

Rust toolchains move from rust-overlay into rustup (#205). `lang-rust` now
installs rustup, whose proxies honor a project's `rust-toolchain.toml` and
keep several channels side by side; a floating overlay nightly did neither.
Two new options choose what activation installs: `atelier.rust.toolchains`
(default `[ "stable" ]`) and `atelier.rust.defaultToolchain` (default
`"stable"`). A missing toolchain is installed with clippy, rustfmt, rust-src
and rust-analyzer; an installed one is never updated on switch
(`rustup update` does that), and a failed download warns instead of
aborting. `rust-analyzer` is a wrapper that always runs the default
toolchain's analyzer, so a project whose pin omits the component still gets
one. `docs/adr/0001-rustup-manages-rust-toolchains.md` records the
trade-off: toolchains now live in `~/.rustup`, outside the store.

The official Bitwarden CLI, `bw`, replaces `rbw` in `base` (#203), after
rbw stopped logging in to bitwarden.com. On darwin it wraps Bitwarden's
prebuilt `bw-oss` binary, held at 2026.8.0 because 2026.9.x crashes on
unlock against bitwarden.com; Linux keeps nixpkgs' build. `bw` has no
agent: `export BW_SESSION="$(bw unlock --raw)"` per shell, and
`rbw get <item>` becomes `bw get password <item>`.

The `copilot` feature and its `config/copilot` submodule are gone (#204). A
new `atelier.obsidianVault` option (default `~/repos/obsidian`, `null`
unsets) exports `OBSIDIAN_VAULT`, which moves out of Claude Code's
`settings.json`, where `$HOME` never expanded. The `claude` and `skills`
submodules move forward (em-dash and commit-message hooks, tiered skill
visibility, the commit and vault skills in the fork), and `just sync` now
relinks skills afterwards.

Major, for three breaking changes: a config listing `copilot` in
`features.extra` fails evaluation (`features.exclude` entries are
harmless, but dead); `pkgs.rust-bin` is no longer in the package set; and
the default Rust toolchain is stable, not nightly. Set
`atelier.rust.defaultToolchain = "nightly"` (and list it in
`atelier.rust.toolchains`) to keep the old default. Also: `flake.lock`
moves forward (#193).

## [v3.2.1](https://github.com/cdprice02/nix-atelier/releases/tag/v3.2.1) -- remote

2026-10-05

Two small changes found by moving four real machines (a Mac, a WSL
instance, an HPC login node and two Raspberry Pis) onto v3.2.0.

Fira Code and its Nerd Font variant move from `shell-tools` to `gui-base`,
so only GUI profiles install them (#196). A headless `minimal` +
`shell-tools` config (an SSH-only Pi, a WSL instance whose terminal is on
the Windows side) previously could only drop them by excluding
`shell-tools` entirely; the terminal that renders the glyphs is on the
client anyway.

caret's directory segment turns magenta in an SSH session, in bash, zsh and
fish, and stays blue locally (#199). caret shows no hostname by design, so a
remote prompt used to look identical to a local one. An explicit
`CARET_COLOR_DIR` still wins, and an nmt test pins the setting ahead of
caret's own source, since caret reads it only once.

Patch rather than minor: no new option and no `lib.mkConfigs` schema
change. A headless profile does lose two packages it had no use for.

## [v3.2.0](https://github.com/cdprice02/nix-atelier/releases/tag/v3.2.0) -- neovim

2026-10-05

Neovim becomes the daily-driver editor: a new `neovim` feature (in `full`)
installs it with every language server, formatter and build tool its config
needs, and links the new `config/nvim` submodule
([cdprice02/nvim-config](https://github.com/cdprice02/nvim-config), modeled
on ThePrimeagen's) to `~/.config/nvim`, live-editable like `config/claude`.
`EDITOR`/`VISUAL` become `nvim` wherever the feature is on. `tmux` turns
Neovim-friendly (true color, no Esc delay, focus events, OSC 52 clipboard,
vi copy mode) and gains `tmux-sessionizer` (`prefix f`), a Claude Code split
(`prefix C`) and a lazygit popup (`prefix g`); `lang-python` adds `jupytext`
(#175). No schema change: a consumer that doesn't want it drops `neovim` via
`features.exclude`.

Two macOS fixes found by actually switching a real Mac to this release
rather than trusting the build. `brew bundle --cleanup`, which
`homebrew.onActivation.cleanup = "zap"` compiles down to, was removed in
Homebrew 7.0, and since `autoUpdate` is on, Homebrew updated itself
mid-activation and then rejected the flag; `cleanup` is now `"none"` (#194).
That failure aborted activation near its end, which advanced the system
profile while leaving `/run/current-system` on the old closure and skipping
Home Manager's user activation entirely, so `docs/troubleshooting.md`
describes the half-applied state too. The cost is that Homebrew is no longer
declarative: `brew bundle cleanup --force` is the manual equivalent.

`gcc` is now Linux-only in the `neovim` feature (#192). Installing it
unconditionally put `cc`/`c++`/`gcc`/`g++` in the profile, and because the
Nix profile precedes `/usr/bin` on `PATH`, every `cc` caller on a Mac
silently moved from Apple clang to GCC 14 on a platform whose SDK expects
clang. macOS uses the clang the Xcode Command Line Tools provide instead,
which also drops 297 MB; tree-sitter parsers were confirmed compiling
against it on a real Intel Mac.

Also: the `claude` and `skills` config submodules move forward (permission
rules culled, auto mode, a context/cache statusline, upstream skills merged),
and `just link-skills` now prunes skill symlinks left dangling by an
upstream removal, which its `-e` guard had been skipping precisely because
they were broken.

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
