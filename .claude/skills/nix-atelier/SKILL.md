---
name: nix-atelier
description: Work on the nix-atelier Nix framework (nix-darwin on macOS, standalone Home Manager on Linux/WSL2/HPC, NixOS build-verified). Use when adding or removing a package, creating or editing a feature module or profile, changing flake inputs, touching the tool catalog, or debugging an eval failure or failed switch. Covers the just interface, the input-pairing invariant, the tool-catalog drift check, the profile compositor, and lib.mkConfigs, the consumable entry point.
---

# nix-atelier

A Nix framework, consumed via `lib.mkConfigs` from a consumer's own flake.nix (see "Consuming this framework" below), not forked and edited. macOS via nix-darwin (Intel and Apple Silicon), any Linux/WSL2/HPC via standalone Home Manager, NixOS build-verified only (no real hardware in this loop). **Nix is the only path: there are no fallback scripts.**

This repo's own `flake.nix` is the first real caller of `lib.mkConfigs`, using a placeholder identity to prove the entry point works standalone.

## Use `just`: it is the interface (working inside a clone of this repo)

```bash
just switch [PROFILE]   # apply for this machine (auto-detects OS and CPU)
just check              # full validation: builds profiles for this system + all lints
just eval-all           # fast: eval every profile without building
just docs               # regenerate docs/profiles.md + docs/tools.md from Nix
just update             # re-resolve ALL flake inputs together
just sync               # update submodules to their tracked branch
just fmt                # nixfmt-rfc-style + statix + deadnix + mdformat, via treefmt
```

`just check` is the gate: it runs `nix flake check` (fully pure, no `--impure`
anywhere in this repo), which includes `formatting` (treefmt: nixfmt-rfc-style,
statix, deadnix, mdformat) alongside the eval-time assertions below. Run it
before proposing a change is done.

A real consumer's own flake.nix has no justfile: they use plain
`home-manager switch`/`darwin-rebuild switch` against their own `lib.mkConfigs`
call directly.

## Three invariants that fail evaluation

These `throw` rather than warn, so a violation breaks *every* profile, not just
the one you touched. Recognise them from the error text.

### 1. Input pairing

Home Manager and nix-darwin are coupled to their nixpkgs release. There are two
independent pairs, and darwin is split by architecture:

| Target                      | nixpkgs          | home-manager          | nix-darwin                      |
| --------------------------- | ---------------- | --------------------- | ------------------------------- |
| Linux/WSL2 + aarch64-darwin | `nixpkgs`        | `home-manager`        | `nix-darwin` (rolling)          |
| x86_64-darwin               | `nixpkgs-darwin` | `home-manager-darwin` | `nix-darwin-x86` (pinned 25.05) |

`checkReleasePair` (`lib/systems.nix`) compares release strings and throws on
mismatch. Only x86_64-darwin is pinned: it is an Intel 2018 MacBook Pro capped
at macOS 13, and 25.05 is the last release supporting both.

**Always update a pair together via `just update`.** Never
`nix flake update <single-input>`. `just update` deliberately takes no input
argument, and it cannot advance the x86_64-darwin pin: those refs are frozen
branches, so re-resolving lands on the same release.

### 2. Tool catalog drift

`modules/tool-catalog.nix` maps package → description for the generated
`docs/tools.md`, and the check runs **both ways**:

- installed but uncatalogued → throws
- catalogued but not installed → throws

So **adding any package to a feature module fails eval until you add a catalog
entry**, and removing one fails until you remove its entry. This is the most
common surprise when editing `modules/features/*.nix`. Packages with no realized
derivation (installed by a vendor script) go in `nonPackageTools` with
`matches = []`. Checked across home, darwin, *and* nixos configs (`self.nixosConfigurations`
included in `installedPackageNames`, `flake.nix`), so a package that only
appears via the nixos kind still needs a catalog entry.

### 3. Unknown feature names

`resolveFeature` (`mkProfile`, `flake.nix`) looks up every name in `tiers.full`,
`features.extra`, and `features.exclude` (a `lib.mkConfigs` call's arguments;
this repo's own placeholder identity sets neither) against
`modules/features.nix`, and throws on a typo. Tiers themselves can't typo:
`minimal = []` and `full = builtins.attrNames features` are derived, not
hand-listed, so there's no second file that could disagree with the registry.

`lib/mkConfigs.nix`'s own schema (`lib.evalModules`, no `freeformType`) adds a
fourth kind of typo protection, one level up: a misspelled field anywhere in a
`mkConfigs` call (`configs.home.<name>.tierr`, say) is a real "option does not
exist" error, not a silently-ignored no-op.

## Layout

```text
flake.nix              inputs, this repo's own placeholder-identity configs, lib.mkConfigs export
lib/
  mkConfigs.nix         the consumable entry point: schema + per-kind builders (home/darwin/nixos)
  systems.nix           checkReleasePair, pkgsFor, and the other per-system dispatch, one definition
templates/default/      `nix flake init -t` scaffold: a minimal consumer flake.nix
modules/
  base.nix             always on: shell, git, ssh, submodule overrides, noreply git email
  env.nix              always on: PATH / writable-prefix policy
  machine.nix           always on: atelier.* options (aws, nativeInstallers, configRepos, sops, submodules)
  features.nix         feature name -> module path registry; full tier = every key in it
  tool-catalog.nix     package -> description (see drift check)
  secrets-sops.nix      always imported, inert unless atelier.sops.file is set
  features/            shell-tools, lang-{rust,node,python}, cloud, claude, copilot, k8s, tmux, git-tools, nix-tools, data, qmk
  gui-{linux,darwin}.nix
system/
  darwin.nix            macOS settings + Homebrew
  nixos.nix             NixOS settings; used by lib/mkConfigs.nix's nixos kind
config/                 git submodules: claude, copilot, git/gitalias
```

`mkProfile { tier, withGui, system, userData, featuresOverride }` composes:
`base + env + machine + secrets-sops + caret ++ tier features ++ extraFeatures (- excludeFeatures) ++ extraModulePaths ++ gui`.

`tier` is `minimal` or `full`; there is no third axis. Machine-specific,
non-public config (identity overrides, private SSH stubs) is not a tracked
file in this repo: it's an absolute path in a `mkConfigs` call's
`features.extraModulePaths`, pointing at a private modules repo. `claude` and
`copilot` (each owning one agent's installer/symlink) are ordinary features
in `full`, gated on nothing; the generic `nativeInstallers`/`configRepos`
mechanism they used to own directly moved to `modules/machine.nix` (#120).

## Consuming this framework

```nix
{
  inputs.nix-atelier.url = "github:cdprice02/nix-atelier";
  outputs = { nix-atelier, ... }:
    nix-atelier.lib.mkConfigs {
      identity = { username; name; email; github.user; };
      configs.home.full = { tier = "full"; system = "x86_64-linux"; };
    };
}
```

`nix flake init -t github:cdprice02/nix-atelier` scaffolds this. Machine-level
integration not in the schema (AWS profile, native installers, private config
repo clones, sops secrets, submodule remote overrides) goes through a config's
own `extraConfig`, targeting `modules/machine.nix`'s `atelier.*` options:

```nix
configs.home.full.extraConfig.atelier.aws.profile = "default";
```

## Adding a package

1. Put it in the right `modules/features/*.nix`, or a new feature file registered in `features.nix` if it doesn't fit an existing one
2. **Add a `modules/tool-catalog.nix` entry** or eval fails
3. `just eval-all` (fast), then `just check`
4. `just docs` if the catalog changed
5. `just switch`

## No `--impure` anywhere

This repo's own `flake.nix` uses a placeholder identity (a literal, not read
from any external file), so `nix flake check`/every apply of this repo's own
configs is fully pure. `just` handles it either way:

```bash
# macOS
sudo darwin-rebuild switch --flake ~/.nix-atelier#<config>
# Linux / WSL2: -b bk is required on first apply or HM refuses to overwrite
home-manager switch --flake ~/.nix-atelier#<profile> -b bk
```

A real consumer's own `extraModulePaths`/`extraSystemModulePaths`/
`hardwareModule` values (if they use them) are a different story: resolving an
absolute path outside the flake's own source still needs `--impure` on
*their* switch, not on `mkConfigs` itself. See `lib/mkConfigs.nix`'s schema
descriptions.

## Identity

`identity` (a `lib.mkConfigs` argument: `username`, `name`, `email`,
`github.{user,id}`) is strictly typed via `lib.evalModules`, no
`freeformType`: it carries only those four fields, nothing else. Everything
that used to live alongside identity in the old `user.nix` shape
(`extraFeatures`, `excludeFeatures`, `extraModulePaths`, `aws`,
`nativeInstallers`, `configRepos`, `secrets`, `sopsFile`, `submodules`) is now
either a top-level `features.*` argument (feature selection: which modules
get imported) or an `atelier.*` option set via a config's `extraConfig`
(machine-level integration: configuring an already-imported module). `sshKey`
is derived from the `email` prefix in `lib/mkConfigs.nix`, not set directly.
`github` feeds the noreply commit email `base.nix` builds (see `gitEmail`
there); `email` itself stays required regardless, since `sshKey` still
derives from it. sops-nix is opt-in per config, triggered by
`atelier.sops.file` being set, with no separate boolean; see
`modules/secrets-sops.nix`.

`atelier.submodules` wires a private remote per submodule: `base.nix`'s
`submoduleOverrides` adds a `private` remote and checks out a local `work` branch
tracking `private/main`. This is how a private Claude config overlay stays out
of the public repo. Needs a real local checkout to work against, at
`atelier.checkoutPath` (default `~/.nix-atelier`, #149).

## Gotchas

- **HM option spellings differ across the two pins.** Where the newer HM renamed
  an option, `base.nix` guards on `options.<path> ? <name>` rather than picking
  one spelling and breaking the other target. Follow that pattern.
- **`config/` submodules are live paths**, not store copies, resolved
  against `atelier.checkoutPath` (default `~/.nix-atelier`). That is why
  `mkOutOfStoreSymlink` is used for `~/.claude` rather than a store copy.
- **`claude.nix` installs no packages.** It is activation hooks running vendor
  installers, guarded by a path test, so once `~/.local/bin/claude` exists the
  hook never runs again and never upgrades. Use `claude update` out of band.
- **Homebrew casks in `system/darwin.nix` are darwin-wide and unconditional.**
  `onActivation.upgrade = true` means they upgrade on every switch, unlike the
  native-installer tools.
- **The nixos kind is build-verified only.** `nix build .#nixosConfigurations.<name>.config.system.build.toplevel` proves a config evaluates and builds; it proves nothing about booting or activation on real hardware.
