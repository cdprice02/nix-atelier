# nix-atelier

[![CI](https://github.com/cdprice02/nix-atelier/actions/workflows/check.yml/badge.svg)](https://github.com/cdprice02/nix-atelier/actions/workflows/check.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A Nix framework for reproducible dev environments, built on [Home Manager](https://github.com/nix-community/home-manager), [nix-darwin](https://github.com/nix-darwin/nix-darwin), and [rust-overlay](https://github.com/oxalica/rust-overlay): macOS (Intel and Apple Silicon) and any Linux/WSL2, same modules, one command. Fork it, fill in `user.nix`, and get a full dev environment on any machine. NixOS support is planned but not implemented; see [issue #5](https://github.com/cdprice02/nix-atelier/issues/5).

Machine-specific and private data — work identity, real secrets, anything that shouldn't be public — never has to live in this repo, forked or not. See [docs/profiles.md](docs/profiles.md) for the profile system, [examples/private-config/](examples/private-config/) for the private-data pattern, and [CONTRIBUTING.md](CONTRIBUTING.md) for how to adapt the framework itself.

## Quick start

See [docs/bootstrap.md](docs/bootstrap.md) for the full setup checklist. The short version:

### Linux / WSL2

```sh
# 1. Install Nix (single-user for WSL2, daemon for native Linux)
sh <(curl -L https://nixos.org/nix/install) --no-daemon
# OR
sh <(curl -L https://nixos.org/nix/install) --daemon

# 2. Enable required experimental features
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# 3. Clone and configure identity
git clone --recurse-submodules https://github.com/cdprice02/nix-atelier.git ~/.nix-atelier
cp ~/.nix-atelier/user.nix.example ~/.nix-atelier/user.nix
$EDITOR ~/.nix-atelier/user.nix  # fill in username, name, email

# 4. Apply (-b bk backs up any pre-existing ~/.bashrc etc. instead of failing)
nix run home-manager -- switch --flake ~/.nix-atelier#full --impure -b bk
```

### macOS

```sh
# 1. Install Nix
sh <(curl -L https://nixos.org/nix/install)

# 2. Clone and configure identity
git clone --recurse-submodules https://github.com/cdprice02/nix-atelier.git ~/.nix-atelier
cp ~/.nix-atelier/user.nix.example ~/.nix-atelier/user.nix
$EDITOR ~/.nix-atelier/user.nix

# 3. Apply. darwin-rebuild does not exist until after the first apply, so run it
#    from the flake. The flag is needed because sudo runs as root, which has no
#    flake config until nix-darwin writes one. Pick the line matching your Mac
#    (`uname -m`): arm64 -> Apple Silicon, x86_64 -> Intel
sudo nix --extra-experimental-features "nix-command flakes" \
  run nix-darwin -- switch --flake ~/.nix-atelier#full-darwin-aarch64 --impure
sudo nix --extra-experimental-features "nix-command flakes" \
  run nix-darwin/nix-darwin-25.05 -- switch --flake ~/.nix-atelier#full-darwin --impure
```

Afterwards `just switch` handles both, appending the right suffix automatically.

## Profiles

Every profile is `tier` (`minimal` or `full`) crossed with GUI (on/off) and CPU
architecture. See [docs/profiles.md](docs/profiles.md) for the full table.
Common ones:

| Profile | Use for |
|---------|---------|
| `full` | Linux/WSL2, full dev toolchain |
| `minimal` | New machine bootstrap or low-resource machine |
| `full-gui` | Desktop Linux, full dev toolchain + GUI apps |
| `full-darwin-aarch64` | macOS, Apple Silicon |

On macOS, pick the config matching your CPU: `-aarch64` for Apple Silicon, the
bare name for Intel. They are not interchangeable; see
[docs/profiles.md](docs/profiles.md).

## Everyday commands

```sh
just switch        # apply this machine's config (detects OS + architecture)
just check         # lint, then validate the flake
just eval-all      # fast: evaluate every profile without building
just update        # re-resolve all flake inputs together
just --list        # everything else
```

## Docs

| | |
|---|---|
| [docs/bootstrap.md](docs/bootstrap.md) | First-time setup, per target |
| [docs/profiles.md](docs/profiles.md) | Every profile and how they compose |
| [docs/tools.md](docs/tools.md) | What each profile installs |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Common first-boot failures |
| [examples/private-config/](examples/private-config/) | Worked example: identity overrides, private packages, secrets |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Forking, local validation, PR standards |
