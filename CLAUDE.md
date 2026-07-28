# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

Personal Nix config. Nix is the only path — no fallback scripts. Supports macOS (nix-darwin), NixOS, and any Linux/WSL2 via standalone Home Manager.

Claude Code and Copilot configs are submodules under `config/` — provisioned automatically by Home Manager on first activation.

## Repo Layout

```text
  flake.nix                    # Entry point — inputs, all configuration outputs
  flake.lock
  user.nix.example             # Identity template (tracked) — copy to user.nix
  user.nix                     # Local identity (gitignored) — never committed
  modules/
    base.nix                   # "core", always on: shell, git, caret prompt, ssh, secrets tooling
    env.nix                    # Always on: PATH / writable-prefix policy for Nix-managed runtimes
    features.nix               # Feature name -> module path registry
    profiles.nix                # Tier -> feature-name list (minimal/dev/server)
    features/
      shell-tools.nix          # tier=dev|server: fonts, zoxide/fzf/direnv, ripgrep/bat/eza/etc.
      lang-rust.nix            # tier=dev: rust-overlay toolchain + cargo tools
      lang-node.nix            # tier=dev: node, fnm, bun
      lang-python.nix          # tier=dev: python3, uv, jupyterlab
      cloud.nix                # tier=dev, or context=work: AWS tooling
      ai.nix                   # tier=dev: claude-code (native installer)
      k8s.nix                  # tier=dev: kubectl, helm, helmfile
      dev-tools.nix            # tier=dev: gh, pre-commit, tmux, qmk
      ops.nix                  # tier=server: rsync, tree, ncdu, htop, tmux
    work.nix                   # Work identity, corporate PEM cert env vars, SSH stubs, imports cloud.nix
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
| Apply config (Mac) | `sudo darwin-rebuild switch --flake ~/.nix-config` |
| Apply config (NixOS) | `sudo nixos-rebuild switch --flake ~/.nix-config` |
| Apply config (Linux/WSL) | `home-manager switch --flake ~/.nix-config#<profile> --impure` |
| Update flake inputs | `nix flake update --flake ~/.nix-config` |

## Architecture

### `flake.nix`

Declares `nixpkgs`, `nix-darwin`, `home-manager`, `rust-overlay` inputs.

#### Input pairing invariant

Home Manager's modules (and nix-darwin) are coupled to their nixpkgs release,
so every home-manager / nix-darwin input must be release-matched to its nixpkgs
input. There are two independent pairs, and the darwin pin is split by
architecture — only x86_64-darwin is pinned:

| Target | nixpkgs | home-manager | nix-darwin | Tracks |
|--------|---------|--------------|------------|--------|
| Linux/WSL2 | `nixpkgs` | `home-manager` | — | rolling (`nixpkgs-unstable` + HM master) |
| aarch64-darwin | `nixpkgs` | `home-manager` | `nix-darwin` | rolling (same as Linux, + nix-darwin master) |
| x86_64-darwin | `nixpkgs-darwin` | `home-manager-darwin` | `nix-darwin-x86` | pinned (`25.05` across all three) |

Only **x86_64-darwin** is pinned: it's an Intel 2018 MacBook Pro capped at
macOS 13, and nixpkgs 25.05 is the last release both supporting x86_64-darwin
and targeting macOS ≤13 (see the `nixpkgs-darwin` input comment). aarch64-darwin
(Apple Silicon) rides the rolling inputs exactly like Linux — it has no such
constraint — so it stays current and never inherits the pinned release's
platform bugs (e.g. 25.05's unbuildable aarch64-darwin dotnet).

`checkReleasePair` in `flake.nix` compares each pair's release strings and
**fails evaluation** on a mismatch — HM's own `enableNixpkgsReleaseCheck` only
warns, which is easy to scroll past. `mkDarwinConfig` asserts the pinned pair
for x86_64-darwin and the rolling pair for aarch64-darwin. Always update both
inputs of a pair together via `just update` (which takes no input argument by
design); never `nix flake update <single-input>`.

`just update` is safe to run from either machine and does **not** advance the
x86_64-darwin pin. The pin is the input *ref* in `flake.nix`, not the revision
in `flake.lock`: re-resolving `nixpkgs-25.05-darwin` / `nix-darwin-25.05` can
only ever land on another 25.05 commit, and those branches are frozen upstream,
so in practice the pinned revisions don't move at all. Only the rolling inputs
(Linux + aarch64-darwin) advance. Retargeting x86_64-darwin to a newer release
means editing the `nixpkgs-darwin`, `nix-darwin-x86`, and `home-manager-darwin`
refs in `flake.nix` by hand — and `checkReleasePair` catches it if they desync.

Because Linux tracks rolling releases, some options must be spelled the way
both HM versions accept. Where the newer HM has renamed or added an option,
`base.nix` guards on `options.<path> ? <name>` (see `programs.ssh.enableDefaultConfig`
and `programs.delta.enableGitIntegration`) rather than picking one version's
spelling and breaking the other.

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

- **Profile vars** (`CLAUDE_PROFILE`, known at build time) — set via `home.sessionVariables` in Nix. (`AWS_PROFILE` is not currently set by this config — tracked separately.)
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
