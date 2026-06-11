# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

Personal Nix config. Nix is the only path — no fallback scripts. Supports macOS (nix-darwin), NixOS, and any Linux/WSL2 via standalone Home Manager.

Claude Code and Copilot configs are submodules under `config/` — provisioned automatically by Home Manager on first activation.

## Repo Layout

```
~/.nix-config/
  flake.nix                    # Entry point — inputs, all configuration outputs
  flake.lock
  user.nix.example             # Identity template (tracked) — copy to user.nix
  user.nix                     # Local identity (gitignored) — never committed
  modules/
    base.nix                   # Universal: CLI tools, fonts, zsh, bash, git, starship, ssh
    dev.nix                    # Dev toolchain: rust-overlay, node, python, cargo tools, tmux, claude-code
    work.nix                   # Work identity, corporate PEM cert env vars, SSH stubs
    server.nix                 # Server tools: rsync, tree, ncdu, htop, tmux
    gui-linux.nix              # Linux GUI: obsidian, alacritty, vscode
    gui-darwin.nix             # macOS GUI: obsidian, alacritty, vscode, osxkeychain
  system/
    darwin.nix                 # macOS system settings + Homebrew
    nixos.nix                  # NixOS system settings
  config/
    git/
      gitalias/                # git submodule (fork of GitAlias/gitalias)
    claude/                    # git submodule — symlinked to ~/.claude by Home Manager
    copilot/                   # git submodule — symlinked to ~/.copilot (personal only)
  docs/
    bootstrap.md               # First-time setup per target
    profiles.md                # Profile reference
    tools.md                   # Tool reference
```

## Key Commands

| Task | Command |
|------|---------|
| Apply config (Mac) | `sudo darwin-rebuild switch --flake ~/.nix-config` (`nix-rb`) |
| Apply config (NixOS) | `sudo nixos-rebuild switch --flake ~/.nix-config` |
| Apply config (Linux/WSL) | `home-manager switch --flake ~/.nix-config#<profile> --impure` (`nix-sw`) |
| Update flake inputs | `nix flake update --flake ~/.nix-config` (`nix-up`) |

## Architecture

### `flake.nix`

Declares `nixpkgs`, `nix-darwin`, `home-manager`, `rust-overlay` inputs.

Outputs:
- `homeConfigurations` — standalone home-manager for Linux/WSL2 (16 keys: personal/work × minimal/dev/server × gui × aarch64)
- `darwinConfigurations` — macOS via nix-darwin + home-manager
- `nixosConfigurations` — NixOS (commented out until hardware-configuration.nix exists)

Identity is loaded from `user.nix` (gitignored, never committed). Copy `user.nix.example` and fill in values. The `user` attrset is built in `flake.nix` from that file — `sshKey` is derived automatically from the email prefix. Requires `--impure` on all `home-manager switch` calls.

### Profile compositor

`mkProfile { context, tier, withGui, system }` produces the module list for a profile:
- `context`: `personal` | `work`
- `tier`: `minimal` | `dev` | `server`
- `withGui`: bool — auto-selects `gui-linux.nix` or `gui-darwin.nix`

Every profile starts with `base.nix`. Darwin configs always include GUI.

`context` is threaded into `specialArgs` so modules can read it. `base.nix` uses it to set `CLAUDE_PROFILE` via `home.sessionVariables` and to gate the Copilot symlink (personal only).

### Secrets

Two tiers:
- **Profile vars** (`CLAUDE_PROFILE`, `AWS_PROFILE`, etc.) — set via `home.sessionVariables` in Nix, known at build time.
- **API keys** — stored in `~/.config/secrets/env` (gitignored, never committed). Shell init sources this file on every session. See `secrets.env.example` at the repo root for the template.

### Submodule overrides

`user.nix` accepts an optional `submodules` attrset. For each key matching a submodule name, Home Manager activation adds a `private` remote and checks out a tracking branch automatically — no manual git setup needed after `home-manager switch`. Leave the block empty to use the default public submodule remotes.

### VS Code

Binary managed by Nix. Extensions and settings via GitHub Settings Sync — nothing declared in Nix.

### SSH

`programs.ssh` in `base.nix` generates `~/.ssh/config`. Key name derived from email prefix (set in `user.nix`). Key generated on first activation if missing.

Work-specific SSH stubs go in `~/.ssh/config.d/work` (written by `work.nix`, included via `Include ~/.ssh/config.d/*`).

### Corporate PEM (work profile only)

Place at `~/.certs/corporate.pem` — never committed. See `docs/bootstrap.md` for the copy command.
