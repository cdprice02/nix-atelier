# Profiles

## Choosing a profile

Every profile is `tier` (`minimal` or `full`) crossed with `gui` (on or
off) crossed with CPU architecture. There's no third axis to reason
about, and nothing to configure beyond that: `full` is every feature this
repo has, `minimal` is none of them.

**New machine?** Start with `minimal` to bootstrap quickly: it installs
only the base tools needed to get Nix and home-manager working. Once
stable, switch to `full` for the complete dev toolchain.

**Daily driver?** Use `full`: Rust, Node, Python, AWS, Kubernetes, tmux,
Claude Code, and everything else in `modules/features.nix`.

**Desktop Linux?** Add `-gui`: adds Obsidian, Alacritty, and VS Code.

**macOS?** Use `full-darwin` (Intel) or `full-darwin-aarch64` (Apple
Silicon): GUI is always included on Darwin, and there is no `minimal`
Mac config.

---

Profiles are composed from three axes by `mkProfile` in `flake.nix`. You
never manually list modules.

```text
tier    : minimal | full
withGui : false | true  (auto-selects gui-linux or gui-darwin)
system  : x86_64-linux | aarch64-linux | x86_64-darwin | aarch64-darwin
```

`tier` expands into a set of named features: `minimal` is `[]`, `full` is
every key in `modules/features.nix`, so a new feature joins `full`
automatically with no list to maintain. `user.nix` can add features
beyond a machine's tier via `extraFeatures`, or drop specific ones via
`excludeFeatures` — see `user.nix.example`.

## Module composition

Hand-maintained, not generated (below the per-profile tables).

| Module | Included when |
|--------|--------------|
| `base.nix` ("core") | always |
| `env.nix` | always |
| every `features/*.nix` | tier = full, or named in `extraFeatures`, minus anything in `excludeFeatures` |
| `extraModulePaths` entries | always, if set in `user.nix` (private, machine-specific modules) |
| `gui-linux.nix` | withGui = true, Linux |
| `gui-darwin.nix` | withGui = true, Darwin (always on macOS) |

`minimal` gets only `core` + `env`: no shell comfort tools, no language
toolchains, no tmux. It keeps `jq`/`wget`/`git-lfs`/`rsync`/`tree`/`ncdu`/`htop`
in `core` itself: bootstrap/scripting/ops utilities, not comfort tools, so
"minimal" means lean rather than feature-free.

## homeConfigurations (Linux / WSL2)

Each profile is built for both `x86_64-linux` and `aarch64-linux`. The `aarch64` variant has a `-aarch64` suffix.

| Profile | Modules | Use for |
|---------|---------|---------|
| `minimal` | core only | Bootstrap or low-resource machine |
| `minimal-aarch64` | core only | Bootstrap or low-resource machine |
| `minimal-gui` | core only + gui-linux | Minimal desktop Linux |
| `minimal-gui-aarch64` | core only + gui-linux | Minimal desktop Linux |
| `full` | core + every feature | Full dev environment: Linux / WSL2 |
| `full-aarch64` | core + every feature | Full dev environment: Linux / WSL2 |
| `full-gui` | core + every feature + gui-linux | Full desktop Linux |
| `full-gui-aarch64` | core + every feature + gui-linux | Full desktop Linux |

Bootstrap:
```sh
nix run home-manager -- switch --flake ~/.nix-atelier#full --impure -b bk
# After first apply, home-manager is on PATH:
home-manager switch --flake ~/.nix-atelier#full --impure -b bk
```

## darwinConfigurations (macOS)

Darwin always includes GUI (`gui-darwin.nix`) and is always the `full` tier.

| Profile | Use for |
|---------|---------|
| `full-darwin` | macOS (Intel) |
| `full-darwin-aarch64` | macOS (Apple Silicon) |

**Pick by CPU, not preference.** `uname -m` prints `arm64` for Apple
Silicon, `x86_64` for Intel. The two are not interchangeable: the Intel
config builds against a pinned nixpkgs 25.05 (nixpkgs-unstable has dropped
x86_64-darwin), while the Apple Silicon config rides the same rolling inputs
as Linux.

Bootstrap: `darwin-rebuild` does not exist until after the first apply, so
the first one runs nix-darwin straight from the flake:
```sh
# Apple Silicon
sudo nix --extra-experimental-features "nix-command flakes" \
  run nix-darwin -- switch --flake ~/.nix-atelier#full-darwin-aarch64 --impure

# Intel: pinned nix-darwin release, matching this repo's 25.05 pin
sudo nix --extra-experimental-features "nix-command flakes" \
  run nix-darwin/nix-darwin-25.05 -- switch --flake ~/.nix-atelier#full-darwin --impure
```

Every later apply can just use `just switch`, which appends the right
suffix for the machine's architecture automatically.

## Customizing your machine

The framework makes most decisions for you; three escape hatches in
`user.nix` cover the rest — see `user.nix.example` for the exact syntax:

- `extraFeatures` — add named features (see `modules/features.nix`) on
  top of a machine's tier, e.g. `minimal` plus just `tmux`.
- `excludeFeatures` — drop features regardless of tier, e.g. `full`
  without `lang-rust`.
- `extraModulePaths` — absolute paths to private, machine-specific
  home-manager modules that live outside this repo entirely (identity
  overrides, extra secrets, anything that shouldn't be public).

Regenerate this file and commit the result after any change that affects
it (a new feature, a renamed tier); the `docs-drift` check fails
otherwise, since this table is generated from the same data `flake.nix`
builds `homeConfigurations` from:
```sh
just docs
```
