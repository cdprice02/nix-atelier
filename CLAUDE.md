# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A Nix framework, consumed rather than forked. `lib.mkConfigs` (`lib/mkConfigs.nix`) is the entry point: a consumer's own flake.nix pins this repo as a flake input and calls it with their identity and the configs they want. Nix is the only path; there are no fallback scripts. Supports macOS (nix-darwin, both Intel and Apple Silicon), any Linux/WSL2 via standalone Home Manager, and NixOS (build-verified only: no real hardware in this loop, see `system/nixos.nix` and `tests/fixtures/nixos-hardware-stub.nix`).

This repo's own `flake.nix` is the first real caller of `lib.mkConfigs`, using a placeholder identity (not meant to be switched to on a real machine) to prove the entry point works standalone rather than as a special-cased internal path.

Claude Code and Copilot configs are submodules under `config/`, provisioned automatically by Home Manager on first activation for a machine that has this repo checked out locally (see `modules/features/claude.nix`'s and `modules/base.nix`'s hardcoded `~/.nix-atelier` assumption, tracked as a gap in issue #149 for a pure flake-input-only consumer).

## Repo Layout

```text
  flake.nix                    # Entry point: inputs, this repo's own placeholder-identity configs, lib.mkConfigs export
  flake.lock
  justfile                     # Task runner, the sole interface (`just --list`)
  .sops.yaml                   # Placeholder-recipient example; real one lives in your private repo
  secrets/secrets.yaml.example # Placeholder-only; real secrets.yaml lives in your private repo
  secrets.env.example          # Template for the manual ~/.config/secrets/env
  treefmt.nix                  # nix fmt / CI formatting config: nixfmt-rfc-style, statix, deadnix, mdformat
  lib/
    mkConfigs.nix               # The consumable entry point (#122): typed schema (lib.evalModules), per-kind builders
    systems.nix                 # Which release pair a system uses, and the resolved pkgs/home-manager/nix-darwin for it
  templates/
    default/                    # `nix flake init -t github:cdprice02/nix-atelier` scaffold: a minimal consumer flake.nix
  modules/
    base.nix                   # "core", always on: shell, git, caret prompt, ssh, secrets tooling, submodule overrides
    env.nix                    # Always on: PATH / writable-prefix policy for Nix-managed runtimes
    machine.nix                 # Always on: atelier.* options (aws, nativeInstallers, configRepos, sops, submodules) (#120)
    features.nix                # Feature name -> module path registry; `full` tier is every key in it
    tool-catalog.nix           # Package -> description, for the generated docs/tools.md
    docs-gen.nix                # Generates docs/profiles.md + docs/tools.md
    secrets-sops.nix            # Always imported, inert unless atelier.sops.file is set (#120)
    lib/
      hm-compat.nix              # Option-name shims across the two home-manager pins
      native-installer.nix       # Shared curl-piped-installer runner, used by claude.nix and machine.nix
      gui-base.nix                # Shared GUI package/theme data for gui-linux.nix/gui-darwin.nix
    features/
      shell-tools.nix          # fonts, zoxide/fzf/direnv, ripgrep/bat/eza/hyperfine/etc.
      lang-rust.nix             # rust-overlay toolchain + cargo tools
      lang-node.nix              # node, fnm, bun
      lang-python.nix            # python3, uv, jupyterlab
      cloud.nix                 # AWS tooling; reads atelier.aws.profile
      claude.nix                 # claude-code (native installer), .claude symlink
      copilot.nix                 # .copilot symlink, sibling of claude.nix
      k8s.nix                    # kubectl, helm, helmfile
      tmux.nix                    # sole owner of tmux config, historyLimit=50000
      git-tools.nix               # gh, glab, difftastic, git-filter-repo, pre-commit
      nix-tools.nix               # nixd, nixfmt-rfc-style
      data.nix                    # duckdb
      qmk.nix                     # qmk (builds fine on x86_64-darwin; verified directly)
    gui-linux.nix               # Linux GUI: obsidian, alacritty, vscode
    gui-darwin.nix               # macOS GUI: obsidian, alacritty, vscode, osxkeychain
  system/
    darwin.nix                 # macOS system settings + Homebrew
    nixos.nix                  # NixOS system settings; referenced by lib/mkConfigs.nix's nixos kind
  config/
    git/
      gitalias/                # git submodule (fork of GitAlias/gitalias)
    claude/                    # git submodule, symlinked to ~/.claude by Home Manager
    copilot/                   # git submodule, symlinked to ~/.copilot by Home Manager
  docs/                        # profiles.md and tools.md are GENERATED; edit docs-gen.nix
    bootstrap.md               # First-time setup per target
    profiles.md                # Profile reference (generated)
    tools.md                   # Tool reference (generated)
    troubleshooting.md         # Common first-boot failures
  tests/
    fixtures/                  # nixos-hardware-stub.nix: synthetic hardware-configuration.nix for build-verify only
    nmt/                       # nmt module tests; wired into `checks` via flake.nix
  examples/private-config/     # Worked example: identity override, private packages, secrets -- copy out, don't run in place
  .github/workflows/
    check.yml                  # get-profiles, flake-check matrix (incl. formatting), eval-all, build matrices
    bootstrap-smoke-test.yml   # Documented bootstrap (template scaffold), from scratch, in a container
    security.yml               # gitleaks
    update-flake-lock.yml      # Weekly atomic `just update` PR
```

## Key Commands

Prefer `just`: it is the sole interface and handles OS/arch dispatch. These are for working inside a clone of this repo itself; a real consumer's own flake.nix (see "Consuming this framework" below) uses plain `home-manager switch`/`darwin-rebuild switch` directly, no justfile.

| Task                                           | Command                                                             |
| ---------------------------------------------- | ------------------------------------------------------------------- |
| Apply config (any OS)                          | `just switch [profile]`                                             |
| Apply config (Mac, explicit)                   | `sudo darwin-rebuild switch --flake ~/.nix-atelier#<config>`        |
| Apply config (Linux/WSL, explicit)             | `home-manager switch --flake ~/.nix-atelier#<profile> -b bk`        |
| First apply on a Mac (no `darwin-rebuild` yet) | `sudo nix run nix-darwin -- switch --flake ~/.nix-atelier#<config>` |
| Update flake inputs                            | `just update`                                                       |
| Validate                                       | `just check` (`nix flake check`, includes formatting/lints)         |
| Regenerate docs                                | `just docs`                                                         |

No `--impure` anywhere: this repo's own flake.nix uses a placeholder identity (a literal, not read from any external file), so `nix flake check`/every apply above is fully pure. `-b bk` is required on a Linux first apply, or Home Manager refuses to overwrite the distro's `~/.bashrc`/`~/.profile`.

`just switch` applies via `nh` (`nh darwin switch`/`nh home switch`), which
prints a package/closure diff before activating and self-elevates internally
when root is needed (no leading `sudo`). Non-interactive by default; trailing
args pass through to nh, e.g. `just switch full -n` for a dry-run diff with
no activation, or `just switch full -a` to pause for confirmation. The
"explicit" rows above call the underlying tools directly, bypassing nh.

## Consuming this framework

A real machine's config lives in its own flake.nix, not in this repo:

```nix
{
  inputs.nix-atelier.url = "github:cdprice02/nix-atelier";
  outputs = { nix-atelier, ... }:
    nix-atelier.lib.mkConfigs {
      identity = { username; name; email; github.user; };
      configs.home.full = { tier = "full"; system = "x86_64-linux"; };
      # configs.darwin.<name> / configs.nixos.<name> also available.
    };
}
```

`nix flake init -t github:cdprice02/nix-atelier` scaffolds exactly this (`templates/default/flake.nix`). `lib/mkConfigs.nix`'s schema (`lib.evalModules`, so a misspelled field is a real error, not a silent no-op) documents every field `configs.home`/`.darwin`/`.nixos` accepts. Machine-level integration that isn't part of the schema (AWS profile, native installers, private config repo clones, sops secrets, submodule remote overrides) is set per-config via `extraConfig`, targeting the `atelier.*` options `modules/machine.nix` declares -- see that file and `modules/secrets-sops.nix`.

## Architecture

### `flake.nix`

Declares `nixpkgs`, `nix-darwin`, `home-manager`, `rust-overlay`, `caret`, `sops-nix`, `treefmt-nix`, `nmt` inputs.

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
`lib/systems.nix` fails evaluation on a mismatch (HM's own
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

- `lib.mkConfigs`: the consumable entry point (see "Consuming this framework" above)
- `homeConfigurations`/`darwinConfigurations`/`nixosConfigurations`: this repo's own placeholder-identity configs, built through `lib.mkConfigs` the same way any consumer's would be. Not meant to be switched to on a real machine.

### `lib/mkConfigs.nix`

`{ identity; configs; features; }` -> `{ homeConfigurations; darwinConfigurations; nixosConfigurations; }`. `configs` splits by kind (`configs.home`/`.darwin`/`.nixos`) rather than one attrset with a `kind` field, so a field belonging to one kind can't leak into another. Home and darwin kinds reuse `mkProfile` (below) unchanged; the nixos kind uses `nixpkgs.lib.nixosSystem` directly, no new flake input. Deliberately does no matrix generation (tier x gui x arch and similar): that's this repo's own convenience for dogfooding every combination, done in `flake.nix` before calling `mkConfigs`, not something the function imposes on every consumer.

### Profile compositor

`mkProfile { tier, withGui, system, userData, featuresOverride }` produces the module list for a profile:

- `tier`: `minimal` | `full`, both derived from `modules/features.nix` (`minimal = []`, `full = builtins.attrNames features`), so a new feature joins `full` automatically with no list to maintain
- `withGui`: bool, auto-selects `gui-linux.nix` or `gui-darwin.nix`

Every profile starts with `base.nix` + `env.nix` + `machine.nix` + `secrets-sops.nix` + caret (all always-on), then the tier's features (`userData.extraFeatures`/`features.extra` in a mkConfigs call, added) and `excludeFeatures`/`features.exclude` (subtracted), then any `extraModulePaths`/`features.extraModulePaths` entries (private, machine-specific modules outside this repo, imported by absolute path), then GUI. `homeConfigurations`/`darwinConfigurations` names for this repo's own configs are generated from tier × gui × arch in `flake.nix`, not hand-listed.

### Secrets

Two tiers:

- **Profile vars** (known at build time): set via `home.sessionVariables` in Nix. `AWS_PROFILE` is opt-in this way, via `atelier.aws.profile` (unset by default: a hardcoded default risks hitting the wrong account).
- **API keys**: stored in `~/.config/secrets/env` (gitignored, never committed). Shell init sources this file on every session. See `secrets.env.example` at the repo root for the manual-copy template. Optionally populated via sops-nix instead: set `atelier.sops.secrets` (a list of names) and `atelier.sops.file` (an absolute path to your own, private secrets.yaml, never this repo's own `secrets/secrets.yaml.example`, which is encrypted for a placeholder recipient nobody holds). `atelier.sops.file`'s presence is the on/off switch, no separate flag. Both are per-machine, so a token that genuinely differs by machine gets its own file per machine rather than one shared file. See `modules/secrets-sops.nix`, `modules/machine.nix`, and `docs/bootstrap.md`.

### Submodule overrides

`atelier.submodules` (set via a config's `extraConfig`) accepts an optional attrset. For each key matching a submodule name, Home Manager activation adds a `private` remote and checks out a tracking branch automatically; no manual git setup needed after `home-manager switch`. Leave the block empty to use the default public submodule remotes.

### VS Code

Binary managed by Nix. Extensions and settings via GitHub Settings Sync; nothing declared in Nix.

### SSH

`programs.ssh` in `base.nix` generates `~/.ssh/config`. Key name derived from email prefix (part of `identity`). Key generated on first activation if missing.

`base.nix` also sets `includes = ["~/.ssh/config.d/*"]` unconditionally, so machine-specific SSH stubs (a work VPN jump host, a private GitLab instance) are unmanaged files dropped there by hand or by an `extraModulePaths` module, never a tracked file in this repo.

### CA bundle env vars (Linux/WSL2 only)

`env.nix` points Nix-managed tools (curl, AWS CLI, `requests`, npm) at the system CA bundle via `SSL_CERT_FILE`/`NODE_EXTRA_CA_CERTS`/`REQUESTS_CA_BUNDLE`, since they don't inherit the system trust store the way distro-packaged binaries do. Not corporate-specific: it just points at whatever `/etc/ssl/certs/ca-certificates.crt` already contains, including a corporate root CA if one's been installed there system-wide.
