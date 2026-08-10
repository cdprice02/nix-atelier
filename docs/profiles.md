# Profiles

## Choosing a profile

**New machine?** Start with `*-minimal` to bootstrap quickly: it installs only the base tools needed to get Nix and home-manager working. Once stable, switch to `work` or `personal` for the full dev toolchain.

**Daily driver (WSL2/Linux)?** Use `work` or `personal`, which include the full dev tier: Rust, Node, Python, AWS, tmux, and Claude Code.

**Headless server or CI?** Use `*-server`: stripped-down, no dev toolchain, large tmux scrollback.

**Desktop Linux?** Use `work-gui` or `personal-gui`: adds Obsidian, Alacritty, and VS Code.

**macOS?** Use `work-darwin` or `personal-darwin`: GUI is always included on Darwin.

---

Profiles are composed from three axes by `mkProfile` in `flake.nix`. You never manually list modules.

```text
context : personal | work
tier    : minimal | dev | server
withGui : false | true  (auto-selects gui-linux or gui-darwin)
```

`tier` expands into a set of named features via `modules/profiles.nix`, each resolved to a module path via `modules/features.nix`. `user.nix` can add extra features beyond a machine's tier via an `extraFeatures` list; see `user.nix.example`.

## Module composition

Hand-maintained, not generated (below the per-profile tables). The one row that doesn't reduce to tier/context/withGui cleanly is `cloud.nix`, included both via the `dev` tier *and* independently via `work.nix`'s own `imports`, which isn't expressed as data anywhere (see `modules/docs-gen.nix`'s own note on this).

| Module | Included when |
|--------|--------------|
| `base.nix` ("core") | always |
| `env.nix` | always |
| `features/shell-tools.nix` | tier = dev or server |
| `features/lang-rust.nix`, `lang-node.nix`, `lang-python.nix` | tier = dev |
| `features/cloud.nix` | tier = dev, or context = work (any tier) |
| `features/ai.nix` | tier = dev |
| `features/k8s.nix` | tier = dev |
| `features/tmux.nix` | tier = dev or server |
| `features/git-tools.nix`, `nix-tools.nix`, `data.nix`, `qmk.nix` | tier = dev |
| `work.nix` | context = work |
| `gui-linux.nix` | withGui = true, Linux |
| `gui-darwin.nix` | withGui = true, Darwin (always on macOS) |

`minimal` gets only `core` + `env`: no `shell-tools` (fonts, zoxide/fzf/direnv, ripgrep/bat/eza/etc.) and none of `dev`'s language toolchains or `tmux`. It keeps `jq`/`wget`/`git-lfs`/`rsync`/`tree`/`ncdu`/`htop` in `core` itself; bootstrap/scripting/ops utilities, not comfort tools, so "minimal" means lean rather than feature-free.

## homeConfigurations (Linux / WSL2)

Each profile is built for both `x86_64-linux` and `aarch64-linux`. The `aarch64` variant has a `-aarch64` suffix.

| Profile | Modules | Use for |
|---------|---------|---------|
| `personal` | core + dev-tier features | Personal Linux / WSL2 |
| `personal-gui` | core + dev-tier features + gui-linux | Personal desktop Linux |
| `personal-minimal` | core only | Bootstrap or low-resource machine |
| `personal-server` | core + server-tier features | Personal headless server |
| `work` | core + dev-tier features + work | Work Linux / WSL2 |
| `work-gui` | core + dev-tier features + work + gui-linux | Work desktop Linux |
| `work-minimal` | core + work (cloud only, via work.nix) | Work bootstrap |
| `work-server` | core + server-tier features + work | Work headless server |

Bootstrap:
```sh
nix run home-manager -- switch --flake ~/.nix-config#work --impure -b bk
# After first apply, home-manager is on PATH:
home-manager switch --flake ~/.nix-config#work --impure -b bk
```

## darwinConfigurations (macOS)

Darwin always includes GUI (`gui-darwin.nix`). Tier is always `dev`.

| Profile | Use for |
|---------|---------|
| `personal-darwin` | Personal macOS (Intel) |
| `personal-darwin-aarch64` | Personal macOS (Apple Silicon) |
| `work-darwin` | Work macOS (Intel) |
| `work-darwin-aarch64` | Work macOS (Apple Silicon) |

**Pick by CPU, not preference.** `uname -m` prints `arm64` for Apple
Silicon, `x86_64` for Intel. The two are not interchangeable: the Intel
configs build against a pinned nixpkgs 25.05 (nixpkgs-unstable has dropped
x86_64-darwin), while the Apple Silicon configs ride the same rolling inputs
as Linux.

Bootstrap: `darwin-rebuild` does not exist until after the first apply, so
the first one runs nix-darwin straight from the flake:
```sh
# Apple Silicon
sudo nix --extra-experimental-features "nix-command flakes" \
  run nix-darwin -- switch --flake ~/.nix-config#personal-darwin-aarch64 --impure

# Intel: pinned nix-darwin release, matching this repo's 25.05 pin
sudo nix --extra-experimental-features "nix-command flakes" \
  run nix-darwin/nix-darwin-25.05 -- switch --flake ~/.nix-config#personal-darwin --impure
```

Every later apply can just use `just switch`, which appends the right
suffix for the machine's architecture automatically.

## Adding a new profile

Add an entry to `modules/profile-list.nix`:

```nix
my-profile = { context = "personal"; tier = "dev"; withGui = false; useFor = "..."; };
```

Regenerate this file and commit the result; the `docs-drift` check fails
otherwise, since the table above is generated from that same list:
```sh
just docs
```

Then apply with:
```sh
home-manager switch --flake ~/.nix-config#my-profile --impure -b bk
```
