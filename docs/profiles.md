# Profiles

## Choosing a profile

**New machine?** Start with `*-minimal` to bootstrap quickly — it installs only the base tools needed to get Nix and home-manager working. Once stable, switch to `work` or `personal` for the full dev toolchain.

**Daily driver (WSL2/Linux)?** Use `work` or `personal` — these include the full dev tier: Rust, Node, Python, AWS, tmux, and Claude Code.

**Headless server or CI?** Use `*-server` — stripped-down, no dev toolchain, large tmux scrollback.

**Desktop Linux?** Use `work-gui` or `personal-gui` — adds Obsidian, Alacritty, and VS Code.

**macOS?** Use `work-darwin` or `personal-darwin` — GUI is always included on Darwin.

---

Profiles are composed from three axes by `mkProfile` in `flake.nix`. You never manually list modules.

```text
context : personal | work
tier    : minimal | dev | server
withGui : false | true  (auto-selects gui-linux or gui-darwin)
```

## Module composition

| Module | Included when |
|--------|--------------|
| `base.nix` | always |
| `dev.nix` | tier = dev |
| `server.nix` | tier = server |
| `work.nix` | context = work |
| `gui-linux.nix` | withGui = true, Linux |
| `gui-darwin.nix` | withGui = true, Darwin (always on macOS) |

## homeConfigurations (Linux / WSL2)

Each profile is built for both `x86_64-linux` and `aarch64-linux`. The `aarch64` variant has a `-aarch64` suffix.

| Profile | Modules | Use for |
|---------|---------|---------|
| `personal` | base + dev | Personal Linux / WSL2 |
| `personal-gui` | base + dev + gui-linux | Personal desktop Linux |
| `personal-minimal` | base | Bootstrap or low-resource machine |
| `personal-server` | base + server | Personal headless server |
| `work` | base + dev + work | Work Linux / WSL2 |
| `work-gui` | base + dev + work + gui-linux | Work desktop Linux |
| `work-minimal` | base + work | Work bootstrap |
| `work-server` | base + server + work | Work headless server |

Bootstrap:
```sh
nix run home-manager -- switch --flake ~/.nix-config#work --impure
# After first apply, home-manager is on PATH:
home-manager switch --flake ~/.nix-config#work --impure
```

## darwinConfigurations (macOS)

Darwin always includes GUI (`gui-darwin.nix`). Tier is always `dev`.

| Profile | Use for |
|---------|---------|
| `personal-darwin` | Personal macOS (Intel) |
| `personal-darwin-aarch64` | Personal macOS (Apple Silicon) |
| `work-darwin` | Work macOS (Intel) |
| `work-darwin-aarch64` | Work macOS (Apple Silicon) |

Bootstrap:
```sh
sudo darwin-rebuild switch --flake ~/.nix-config#personal-darwin --impure
```

## Adding a new profile

Add a `mkLinuxPair` call in the `homeConfigurations` block of `flake.nix`:

```nix
(mkLinuxPair { name = "my-profile"; context = "personal"; tier = "dev"; withGui = false; })
```

Then apply with:
```sh
home-manager switch --flake ~/.nix-config#my-profile --impure
```
