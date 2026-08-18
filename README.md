# nix-atelier

[![CI](https://github.com/cdprice02/nix-atelier/actions/workflows/check.yml/badge.svg)](https://github.com/cdprice02/nix-atelier/actions/workflows/check.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A Nix framework for reproducible dev environments, built on [Home Manager](https://github.com/nix-community/home-manager), [nix-darwin](https://github.com/nix-darwin/nix-darwin), and [rust-overlay](https://github.com/oxalica/rust-overlay): macOS (Intel and Apple Silicon), any Linux/WSL2, and NixOS (build-verified), same modules, one command. Consumed, not forked: pin it as a flake input, call `lib.mkConfigs` with your identity, get a full dev environment on any machine.

Machine-specific and private data (work identity, real secrets, anything that shouldn't be public) never has to live in this repo, or in a fork of it: it lives in your own flake.nix instead. See [docs/profiles.md](docs/profiles.md) for the profile system, [examples/private-config/](examples/private-config/) for the private-data pattern, and [CONTRIBUTING.md](CONTRIBUTING.md) for how to adapt the framework itself.

## Why this, not something else

- **vs. [nix-starter-configs](https://github.com/Misterio77/nix-starter-configs) or plain dotfiles**: those are templates you copy and make your own; there's no ongoing relationship to the upstream repo once you fork. nix-atelier is a flake input you pin and bump, so framework fixes and new features arrive the way a library dependency update does, not by re-merging a divergent fork.
- **vs. [snowfall-lib](https://github.com/snowfallorg/lib) or [ez-configs](https://github.com/ehllie/ez-configs)**: both are directory-convention-driven layers on top of [flake-parts](https://flake.parts/), generating your `nixosConfigurations`/`homeConfigurations` from where files sit in your tree. nix-atelier deliberately isn't a flake-parts module (see [Discussion #74](https://github.com/cdprice02/nix-atelier/discussions/74) for the reasoning): `lib.mkConfigs` is one plain, typed function you call explicitly, and it also ships an opinionated, curated feature set (a specific shell/git/language toolchain, already selected and catalogued) rather than being a generic scaffold with no opinion on what you install.
- **vs. hand-rolled dotfiles with no Nix at all**: no reproducibility across machines, no pinned dependency versions, and every "works on my machine" fix has to be re-applied by hand everywhere else.

## Quick start

See [docs/bootstrap.md](docs/bootstrap.md) for the full setup checklist. The short version:

```sh
# 1. Install Nix
sh <(curl -L https://nixos.org/nix/install) --no-daemon   # WSL2 / single-user Linux
sh <(curl -L https://nixos.org/nix/install)                # macOS / multi-user Linux

# 2. Enable required experimental features
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# 3. Scaffold your own config and fill in your identity
mkdir my-config && cd my-config
nix flake init -t github:cdprice02/nix-atelier
$EDITOR flake.nix   # fill in identity + at least one config
nix flake check

# 4. Apply (-b bk backs up any pre-existing ~/.bashrc etc. instead of failing)
nix run home-manager -- switch --flake .#<name> -b bk        # Linux/WSL2
sudo nix run nix-darwin -- switch --flake .#<name>            # macOS, first apply
```

See [templates/default/README.md](templates/default/flake.nix) for what the scaffolded `flake.nix` looks like and where to find every field it accepts.

<!-- TODO: a short terminal recording of `just switch` here, showing nh's
     diff-before-activate output -- the single most distinctive thing to
     show for a project whose entire output is a terminal environment. -->

## Profiles

Every profile is `tier` (`minimal` or `full`) crossed with GUI (on/off) and CPU
architecture. See [docs/profiles.md](docs/profiles.md) for the full table.
Common ones:

| Profile               | Use for                                       |
| --------------------- | --------------------------------------------- |
| `full`                | Linux/WSL2, full dev toolchain                |
| `minimal`             | New machine bootstrap or low-resource machine |
| `full-gui`            | Desktop Linux, full dev toolchain + GUI apps  |
| `full-darwin-aarch64` | macOS, Apple Silicon                          |

On macOS, pick the config matching your CPU: `-aarch64` for Apple Silicon, the
bare name for Intel. They are not interchangeable; see
[docs/profiles.md](docs/profiles.md).

## FAQ

**Do I need to already know Nix?**
Some comfort with the language helps for extending the framework (adding a feature, writing a private machine module), but consuming it as-is just means filling in a ~15-line `flake.nix` and running one command. See the Quick start above and [docs/bootstrap.md](docs/bootstrap.md).

**Why not flake-parts?**
Genuinely considered and declined: see [Discussion #74](https://github.com/cdprice02/nix-atelier/discussions/74). Short version: a plain, typed function (`lib.mkConfigs`) is simpler to understand and debug than a module-system layer on top of one, for the kind of composition this framework needs.

**Is NixOS supported?**
Yes, as a third config kind alongside Home Manager and nix-darwin, but build-verified only: there's no real NixOS hardware in this project's own CI loop, so a NixOS config is proven to evaluate and build, not to boot.

**What if I need a tool that isn't in the default feature set?**
`features.extra`/`features.exclude` add or drop named features per config; `features.extraModulePaths` layers in your own private Home Manager modules entirely outside this repo. See [docs/profiles.md](docs/profiles.md) and [examples/private-config/](examples/private-config/).

**Why does the `full` tier run a vendor install script on first activation?**
It does, for Claude Code specifically (and anything you declare via `atelier.nativeInstallers`). See [SECURITY.md](SECURITY.md)'s scope section for what that means.

## Everyday commands

Inside a clone of this repo itself (contributing to the framework, not just consuming it):

```sh
just switch        # apply this machine's config (detects OS + architecture)
just check         # nix flake check, includes formatting/lints
just eval-all      # fast: evaluate every profile without building
just update        # re-resolve all flake inputs together
just --list        # everything else
```

## Docs

|                                                      |                                                                      |
| ---------------------------------------------------- | -------------------------------------------------------------------- |
| [ARCHITECTURE.md](ARCHITECTURE.md)                   | How the framework thinks: compositor, extension points, drift guards |
| [CHANGELOG.md](CHANGELOG.md)                         | Version history, and where to find each release's full notes         |
| [docs/bootstrap.md](docs/bootstrap.md)               | First-time setup, per target                                         |
| [docs/profiles.md](docs/profiles.md)                 | Every profile and how they compose                                   |
| [docs/tools.md](docs/tools.md)                       | What each profile installs                                           |
| [docs/troubleshooting.md](docs/troubleshooting.md)   | Common first-boot failures                                           |
| [examples/private-config/](examples/private-config/) | Worked example: identity overrides, private packages, secrets        |
| [CONTRIBUTING.md](CONTRIBUTING.md)                   | Consuming vs. contributing, local validation, PR standards           |

## Contributing

New to the codebase? Issues labeled
[`good first issue`](https://github.com/cdprice02/nix-atelier/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22)
are small and self-contained. For the bigger picture of where this is
heading, see the [milestones](https://github.com/cdprice02/nix-atelier/milestones).
See [CONTRIBUTING.md](CONTRIBUTING.md) for what kind of change belongs in a
PR here versus in your own `flake.nix`.
