# nix-config

[![CI](https://github.com/cdprice02/nix-config/actions/workflows/check.yml/badge.svg)](https://github.com/cdprice02/nix-config/actions/workflows/check.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Personal Nix config managed with [Home Manager](https://github.com/nix-community/home-manager), [nix-darwin](https://github.com/LnL7/nix-darwin), and [rust-overlay](https://github.com/oxalica/rust-overlay). Supports macOS, NixOS, and any Linux/WSL2.

Structured as a composable framework — fork it, fill in `user.nix`, and get a full dev environment on any machine with one command. See [docs/profiles.md](docs/profiles.md) for the profile system and [CONTRIBUTING.md](CONTRIBUTING.md) for how to adapt it to your own setup.

## Quick start

See [docs/bootstrap.md](docs/bootstrap.md) for the full setup checklist. The short version:

### Linux / WSL2

```sh
# 1. Install Nix (single-user for WSL2, daemon for native Linux)
sh <(curl -L https://nixos.org/nix/install) --no-daemon   # WSL2
sh <(curl -L https://nixos.org/nix/install)               # native Linux

# 2. Enable flakes (single-user only)
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# 3. Clone and configure identity
git clone --recurse-submodules git@github.com:cdprice02/nix-config.git ~/.nix-config
cp ~/.nix-config/user.nix.example ~/.nix-config/user.nix
$EDITOR ~/.nix-config/user.nix  # fill in username, name, email

# 4. Apply
nix run home-manager -- switch --flake ~/.nix-config#work --impure      # work machine
nix run home-manager -- switch --flake ~/.nix-config#personal --impure  # personal machine
```

### macOS

```sh
# 1. Install Nix
sh <(curl -L https://nixos.org/nix/install)

# 2. Clone and configure identity
git clone --recurse-submodules git@github.com:cdprice02/nix-config.git ~/.nix-config
cp ~/.nix-config/user.nix.example ~/.nix-config/user.nix
$EDITOR ~/.nix-config/user.nix

# 3. Apply
sudo darwin-rebuild switch --flake ~/.nix-config#personal-darwin --impure
```

## Daily commands

| Task | Command |
|------|---------|
| Apply config (Linux) | `nix-sw` → `home-manager switch --flake ~/.nix-config#<profile> --impure` |
| Apply config (Mac) | `nix-rb` → `sudo darwin-rebuild switch --flake ~/.nix-config#<profile> --impure` |
| Update flake inputs | `nix-up` → `nix flake update --flake ~/.nix-config` |

## Profiles

See [docs/profiles.md](docs/profiles.md) for the full table. Common ones:

| Profile | Use for |
|---------|---------|
| `work` | Work Linux/WSL2 — dev toolchain + work identity + corporate PEM |
| `personal` | Personal Linux/WSL2 — dev toolchain |
| `personal-minimal` | New machine bootstrap or low-resource machine |
| `work-darwin` | Work macOS — dev + GUI |

## Repo layout

```
flake.nix          # Entry point — profile compositor, all outputs
user.nix.example   # Identity template — copy to user.nix and fill in
modules/
  base.nix         # Universal baseline (all profiles)
  dev.nix          # Dev toolchain: Rust, Node, Python, cargo tools, tmux, Claude Code
  work.nix         # Work: git identity, corporate PEM env vars, SSH stubs
  server.nix       # Server tools: rsync, tree, ncdu, htop, tmux
  gui-linux.nix    # Linux GUI: obsidian, alacritty, vscode
  gui-darwin.nix   # macOS GUI: obsidian, alacritty, vscode, osxkeychain
system/
  darwin.nix       # macOS system settings + Homebrew
  nixos.nix        # NixOS system settings
config/
  git/gitalias/    # git submodule — fork of GitAlias/gitalias
docs/
  bootstrap.md     # First-time setup checklist
  profiles.md      # Profile reference
  tools.md         # Tool reference
```

