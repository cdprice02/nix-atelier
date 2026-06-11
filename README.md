# nix-config

Personal Nix config managed with [Home Manager](https://github.com/nix-community/home-manager), [nix-darwin](https://github.com/LnL7/nix-darwin), and [rust-overlay](https://github.com/oxalica/rust-overlay). Supports macOS, NixOS, and any Linux/WSL2.

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
git clone git@github.com:cdprice02/nix-config.git ~/.nix-config
git -C ~/.nix-config submodule update --init
cp ~/.nix-config/user.nix.example ~/.nix-config/user.nix
$EDITOR ~/.nix-config/user.nix  # fill in username, name, email

# 4. Apply
nix run home-manager -- switch --flake ~/.nix-config#work --impure      # work machine
nix run home-manager -- switch --flake ~/.nix-config#personal --impure  # personal machine
```

### macOS

```sh
git clone git@github.com:cdprice02/nix-config.git ~/.nix-config
git -C ~/.nix-config submodule update --init
cp ~/.nix-config/user.nix.example ~/.nix-config/user.nix
$EDITOR ~/.nix-config/user.nix
sudo darwin-rebuild switch --flake ~/.nix-config#personal-darwin
```

## Daily commands

| Task | Command |
|------|---------|
| Apply config (Linux) | `nix-sw` → `home-manager switch --flake ~/.nix-config#<profile> --impure` |
| Apply config (Mac) | `nix-rb` → `sudo darwin-rebuild switch --flake ~/.nix-config` |
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

## Separate repos

Claude Code and Copilot configs are not in this repo:

```sh
git clone git@github.com:cdprice02/claude-config ~/.claude
git clone git@github.com:cdprice02/copilot-config ~/.copilot
```
