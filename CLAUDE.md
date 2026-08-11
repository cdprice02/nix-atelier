# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

Personal Nix config. Nix is the only path; there are no fallback scripts. Supports macOS (nix-darwin, both Intel and Apple Silicon) and any Linux/WSL2 via standalone Home Manager. NixOS is **not** supported yet: `system/nixos.nix` exists but no flake output references it (tracked in issue #5).

Claude Code and Copilot configs are submodules under `config/`, provisioned automatically by Home Manager on first activation.

## Repo Layout

```text
  flake.nix                    # Entry point: inputs, all configuration outputs
  flake.lock
  justfile                     # Task runner, the sole interface (`just --list`)
  user.nix.example             # Identity template (tracked); copy to user.nix
  user.nix                     # Local identity (gitignored); never committed
  .sops.yaml                   # Placeholder-recipient example; real one lives in your private repo
  secrets/secrets.yaml.example # Placeholder-only; real secrets.yaml lives in your private repo
  secrets.env.example          # Template for the manual ~/.config/secrets/env
  statix.toml                  # statix lint config (one rule disabled; see issue #46)
  treefmt.nix                  # nix fmt / CI formatting config: nixfmt-rfc-style, statix, deadnix, mdformat
  modules/
    base.nix                   # "core", always on: shell, git, caret prompt, ssh, secrets tooling
    env.nix                    # Always on: PATH / writable-prefix policy for Nix-managed runtimes
    features.nix               # Feature name -> module path registry; `full` tier is every key in it
    tool-catalog.nix           # Package -> description, for the generated docs/tools.md
    docs-gen.nix               # Generates docs/profiles.md + docs/tools.md
    secrets-sops.nix           # Opt-in sops-nix wiring, triggered by user.nix: sopsFile = "..."
    lib/
      hm-compat.nix            # Option-name shims across the two home-manager pins
    features/
      shell-tools.nix          # fonts, zoxide/fzf/direnv, ripgrep/bat/eza/hyperfine/etc.
      lang-rust.nix            # rust-overlay toolchain + cargo tools
      lang-node.nix            # node, fnm, bun
      lang-python.nix          # python3, uv, jupyterlab
      cloud.nix                # AWS tooling
      claude.nix               # claude-code (native installer), .claude symlink; user.nativeInstallers/configRepos for anything else
      copilot.nix              # .copilot symlink, sibling of claude.nix
      k8s.nix                  # kubectl, helm, helmfile
      tmux.nix                 # sole owner of tmux config, historyLimit=50000
      git-tools.nix            # gh, glab, difftastic, git-filter-repo, pre-commit
      nix-tools.nix            # nixd, nixfmt-rfc-style
      data.nix                 # duckdb
      qmk.nix                  # qmk (builds fine on x86_64-darwin; verified directly)
    gui-linux.nix              # Linux GUI: obsidian, alacritty, vscode
    gui-darwin.nix             # macOS GUI: obsidian, alacritty, vscode, osxkeychain
  system/
    darwin.nix                 # macOS system settings + Homebrew
    nixos.nix                  # UNREFERENCED; no nixosConfigurations output (issue #5)
  config/
    git/
      gitalias/                # git submodule (fork of GitAlias/gitalias)
      gitalias.txt             # ORPHANED stale duplicate; see issue #47
    claude/                    # git submodule, symlinked to ~/.claude by Home Manager
    copilot/                   # git submodule, symlinked to ~/.copilot by Home Manager
  docs/                        # profiles.md and tools.md are GENERATED; edit docs-gen.nix
    bootstrap.md               # First-time setup per target
    profiles.md                # Profile reference (generated)
    tools.md                   # Tool reference (generated)
    troubleshooting.md         # Common first-boot failures
  examples/private-config/     # Worked example: identity override, private packages, secrets -- copy out, don't run in place
  .github/workflows/
    check.yml                  # eval-all, flake-check, 4 lints, build matrices
    bootstrap-smoke-test.yml   # Documented bootstrap, from scratch, in a container
    security.yml               # gitleaks
    update-flake-lock.yml      # Weekly atomic `just update` PR
```

## Key Commands

Prefer `just`: it is the sole interface and handles OS/arch dispatch.

| Task                                           | Command                                                                      |
| ---------------------------------------------- | ---------------------------------------------------------------------------- |
| Apply config (any OS)                          | `just switch [profile]`                                                      |
| Apply config (Mac, explicit)                   | `sudo darwin-rebuild switch --flake ~/.nix-atelier#<config> --impure`        |
| Apply config (Linux/WSL, explicit)             | `home-manager switch --flake ~/.nix-atelier#<profile> --impure -b bk`        |
| First apply on a Mac (no `darwin-rebuild` yet) | `sudo nix run nix-darwin -- switch --flake ~/.nix-atelier#<config> --impure` |
| Update flake inputs                            | `just update`                                                                |
| Validate                                       | `just check` (lints + `nix flake check`)                                     |
| Regenerate docs                                | `just docs`                                                                  |

`--impure` is required on every apply (`user.nix` is read via `builtins.getEnv`).
`-b bk` is required on a Linux first apply, or Home Manager refuses to overwrite
the distro's `~/.bashrc`/`~/.profile`. NixOS has no entry here because there is
no `nixosConfigurations` output to apply.

## Architecture

### `flake.nix`

Declares `nixpkgs`, `nix-darwin`, `home-manager`, `rust-overlay` inputs.

#### Input pairing invariant

Home Manager's modules (and nix-darwin) are coupled to their nixpkgs release,
so every home-manager / nix-darwin input must be release-matched to its
nixpkgs input. Two independent pairs:

| Target         | nixpkgs          | home-manager          | nix-darwin       | Tracks                                       |
| -------------- | ---------------- | --------------------- | ---------------- | -------------------------------------------- |
| Linux/WSL2     | `nixpkgs`        | `home-manager`        | none             | rolling (`nixpkgs-unstable` + HM master)     |
| aarch64-darwin | `nixpkgs`        | `home-manager`        | `nix-darwin`     | rolling (same as Linux, + nix-darwin master) |
| x86_64-darwin  | `nixpkgs-darwin` | `home-manager-darwin` | `nix-darwin-x86` | pinned (`25.05` across all three)            |

Only x86_64-darwin is pinned: an Intel 2018 MacBook Pro capped at macOS 13,
and 25.05 is the last release supporting both. `checkReleasePair` in
`flake.nix` fails evaluation on a mismatch (HM's own
`enableNixpkgsReleaseCheck` only warns, which is easy to miss). Always update
both inputs of a pair together via `just update`, which takes no input
argument by design; never `nix flake update <single-input>`. Retargeting the
pin means editing the `nixpkgs-darwin`, `nix-darwin-x86`, and
`home-manager-darwin` refs in `flake.nix` by hand.

Because Linux tracks rolling releases, some options must be spelled the way
both HM versions accept. Where the newer HM has renamed or added an option,
`base.nix` guards on `options.<path> ? <name>` (see `programs.ssh.enableDefaultConfig`
and `programs.delta.enableGitIntegration`) rather than picking one version's
spelling and breaking the other.

Outputs:

- `homeConfigurations`: standalone home-manager for Linux/WSL2 (8 keys: {minimal,full} × gui × aarch64)
- `darwinConfigurations`: macOS via nix-darwin + home-manager (2 keys: full-darwin × aarch64; always `full` tier, always GUI)
- `nixosConfigurations`: not implemented (tracked in issue #5); no output exists yet, needs a `mkNixosConfig` helper and a target machine's `hardware-configuration.nix`

Identity is loaded from `user.nix` (gitignored, never committed). Copy `user.nix.example` and fill in values. The `user` attrset is built in `flake.nix` from that file; `sshKey` is derived automatically from the email prefix. Requires `--impure` on all `home-manager switch` calls.

### Profile compositor

`mkProfile { tier, withGui, system }` produces the module list for a profile:

- `tier`: `minimal` | `full`, both derived from `modules/features.nix` (`minimal = []`, `full = builtins.attrNames features`) — a new feature joins `full` automatically, no list to maintain
- `withGui`: bool, auto-selects `gui-linux.nix` or `gui-darwin.nix`

Every profile starts with `base.nix` + `env.nix` + caret, then the tier's
features, then `user.nix`'s `extraFeatures` (added) and `excludeFeatures`
(subtracted), then any `extraModulePaths` entries (private, machine-specific
modules outside this repo, imported by absolute path), then GUI, then the
opt-in sops modules. `homeConfigurations`/`darwinConfigurations` names are
generated from tier × gui × arch in `flake.nix`, not hand-listed.

### Secrets

Two tiers:

- **Profile vars** (known at build time): set via `home.sessionVariables` in Nix. `AWS_PROFILE` is opt-in this way, via `user.nix`'s `aws.profile` field (unset by default: a hardcoded default risks hitting the wrong account).
- **API keys**: stored in `~/.config/secrets/env` (gitignored, never committed). Shell init sources this file on every session. See `secrets.env.example` at the repo root for the manual-copy template. Optionally populated via sops-nix instead: set `user.nix`'s `secrets` (a list of names) and `sopsFile` (an absolute path to your own, private secrets.yaml — never this repo's own `secrets/secrets.yaml.example`, which is encrypted for a placeholder recipient nobody holds). `sopsFile`'s presence is the on/off switch, no separate flag. Both are per-machine, so a token that genuinely differs by machine gets its own file per machine rather than one shared file. See `modules/secrets-sops.nix` and `docs/bootstrap.md`.

### Submodule overrides

`user.nix` accepts an optional `submodules` attrset. For each key matching a submodule name, Home Manager activation adds a `private` remote and checks out a tracking branch automatically; no manual git setup needed after `home-manager switch`. Leave the block empty to use the default public submodule remotes.

### VS Code

Binary managed by Nix. Extensions and settings via GitHub Settings Sync; nothing declared in Nix.

### SSH

`programs.ssh` in `base.nix` generates `~/.ssh/config`. Key name derived from email prefix (set in `user.nix`). Key generated on first activation if missing.

`base.nix` also sets `includes = ["~/.ssh/config.d/*"]` unconditionally, so machine-specific SSH stubs (a work VPN jump host, a private GitLab instance) are unmanaged files dropped there by hand or by an `extraModulePaths` module — never a tracked file in this repo.

### CA bundle env vars (Linux/WSL2 only)

`env.nix` points Nix-managed tools (curl, AWS CLI, `requests`, npm) at the system CA bundle via `SSL_CERT_FILE`/`NODE_EXTRA_CA_CERTS`/`REQUESTS_CA_BUNDLE`, since they don't inherit the system trust store the way distro-packaged binaries do. Not corporate-specific: it just points at whatever `/etc/ssl/certs/ca-certificates.crt` already contains, including a corporate root CA if one's been installed there system-wide.
