# nix-atelier

[![CI](https://github.com/cdprice02/nix-atelier/actions/workflows/check.yml/badge.svg)](https://github.com/cdprice02/nix-atelier/actions/workflows/check.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A Nix framework for reproducible dev environments, built on [Home Manager](https://github.com/nix-community/home-manager), [nix-darwin](https://github.com/nix-darwin/nix-darwin), and [rust-overlay](https://github.com/oxalica/rust-overlay): macOS (Intel and Apple Silicon), any Linux/WSL2, and NixOS (build-verified), same modules, one command. Consumed, not forked: pin it as a flake input, call `lib.mkConfigs` with your identity, get a full dev environment on any machine.

Machine-specific and private data (work identity, real secrets, anything that shouldn't be public) never has to live in this repo, or in a fork of it: it lives in your own flake.nix instead. See [docs/profiles.md](docs/profiles.md) for the profile system, [examples/private-config/](examples/private-config/) for the private-data pattern, and [CONTRIBUTING.md](CONTRIBUTING.md) for how to adapt the framework itself.

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

|                                                      |                                                               |
| ---------------------------------------------------- | ------------------------------------------------------------- |
| [docs/bootstrap.md](docs/bootstrap.md)               | First-time setup, per target                                  |
| [docs/profiles.md](docs/profiles.md)                 | Every profile and how they compose                            |
| [docs/tools.md](docs/tools.md)                       | What each profile installs                                    |
| [docs/troubleshooting.md](docs/troubleshooting.md)   | Common first-boot failures                                    |
| [examples/private-config/](examples/private-config/) | Worked example: identity overrides, private packages, secrets |
| [CONTRIBUTING.md](CONTRIBUTING.md)                   | Forking, local validation, PR standards                       |
