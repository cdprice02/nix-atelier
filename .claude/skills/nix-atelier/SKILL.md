---
name: nix-atelier
description: Work on the personal Nix configuration repo (nix-darwin on macOS, standalone Home Manager on Linux/WSL2/HPC). Use when adding or removing a package, creating or editing a feature module or profile, changing flake inputs, touching the tool catalog, or debugging an eval failure or failed switch. Covers the just interface, the input-pairing invariant, the tool-catalog drift check, the profile compositor, and why --impure is required.
---

# nix-atelier

Personal Nix config at `~/.nix-atelier`. macOS via nix-darwin (Intel and Apple
Silicon), any Linux/WSL2/HPC via standalone Home Manager. **Nix is the only
path: there are no fallback scripts.** NixOS is not supported: `system/nixos.nix`
exists but no flake output references it.

## Use `just`: it is the interface

```bash
just switch [PROFILE]   # apply for this machine (auto-detects OS and CPU)
just check              # full validation: builds profiles for this system + all lints
just eval-all           # fast: eval every profile without building
just docs               # regenerate docs/profiles.md + docs/tools.md from Nix
just update             # re-resolve ALL flake inputs together
just sync               # update submodules to their tracked branch
just fmt                # nixfmt-rfc-style + statix + deadnix + mdformat, via treefmt
```

`just check` is the gate: it runs `nix flake check`, which includes
`formatting` (treefmt: nixfmt-rfc-style, statix, deadnix, mdformat) alongside
the eval-time assertions below. Run it before proposing a change is done.

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

`checkReleasePair` (`grep -n checkReleasePair flake.nix` to find it; line
numbers here would rot) compares release strings and throws on mismatch. Only
x86_64-darwin is pinned: it is an Intel 2018 MacBook Pro capped at macOS 13,
and 25.05 is the last release supporting both.

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
`matches = []`.

### 3. Unknown feature names

`resolveFeature` (in `flake.nix`) looks up every name in `tiers.full`,
`user.extraFeatures`, and `user.excludeFeatures` against
`modules/features.nix`, and throws on a typo. Tiers themselves can't typo:
`minimal = []` and `full = builtins.attrNames features` are derived, not
hand-listed, so there's no second file that could disagree with the registry.

## Layout

```text
flake.nix              inputs, outputs, mkProfile, the three checks above
modules/
  base.nix             always on: shell, git, ssh, submodule overrides, noreply git email
  env.nix              always on: PATH / writable-prefix policy
  features.nix         feature name -> module path registry; full tier = every key in it
  tool-catalog.nix     package -> description (see drift check)
  features/            shell-tools, lang-{rust,node,python}, cloud, claude, copilot, k8s, tmux, git-tools, nix-tools, data, qmk
  gui-{linux,darwin}.nix
system/darwin.nix      macOS settings + Homebrew
config/                git submodules: claude, copilot, git/gitalias
```

`mkProfile { tier, withGui, system }` composes:
`base + env + caret ++ tier features ++ extraFeatures (- excludeFeatures) ++ extraModulePaths ++ gui ++ sops`.

`tier` is `minimal` or `full`; there is no third axis. Machine-specific,
non-public config (identity overrides, private SSH stubs) is not a tracked
file in this repo: it's an absolute path in `user.nix`'s
`extraModulePaths`, pointing at a private modules repo. `claude` and
`copilot` (each owning one agent's installer/symlink) are ordinary features
in `full`, gated on nothing.

## Adding a package

1. Put it in the right `modules/features/*.nix`, or a new feature file registered in `features.nix` if it doesn't fit an existing one
2. **Add a `modules/tool-catalog.nix` entry** or eval fails
3. `just eval-all` (fast), then `just check`
4. `just docs` if the catalog changed
5. `just switch`

## `--impure` is required

Every apply needs it: `user.nix` is read via `builtins.getEnv`, and submodule
paths are referenced live rather than through the store. `just` handles this.
Doing it by hand:

```bash
# macOS
sudo darwin-rebuild switch --flake ~/.nix-atelier#<config> --impure
# Linux / WSL2: -b bk is required on first apply or HM refuses to overwrite
home-manager switch --flake ~/.nix-atelier#<profile> --impure -b bk
```

## Identity

`user.nix` is gitignored and never committed; `user.nix.example` is the template.
Optional keys: `profile`, `extraFeatures`, `excludeFeatures`, `extraModulePaths`,
`github.{user,id}`, `aws.profile`, `nativeInstallers`, `configRepos`,
`secrets`, `sopsFile`, `submodules`. `sshKey` is derived from the email
prefix in flake.nix, not set directly. `github` feeds the noreply commit
email `base.nix` builds (see `gitEmail` there); `email` itself stays
required regardless, since `sshKey` still derives from it. sops-nix is
opt-in per machine, triggered by `sopsFile` being set, with no separate
boolean; see `modules/secrets-sops.nix`.

`submodules` wires a private remote per submodule: `base.nix`'s
`submoduleOverrides` adds a `private` remote and checks out a local `work` branch
tracking `private/main`. This is how a private Claude config overlay stays out
of the public repo.

## Gotchas

- **HM option spellings differ across the two pins.** Where the newer HM renamed
  an option, `base.nix` guards on `options.<path> ? <name>` rather than picking
  one spelling and breaking the other target. Follow that pattern.
- **`config/` submodules are live paths**, not store copies. That is why
  `--impure` is needed and why `mkOutOfStoreSymlink` is used for `~/.claude`.
- **`claude.nix` installs no packages.** It is activation hooks running vendor
  installers, guarded by a path test, so once `~/.local/bin/claude` exists the
  hook never runs again and never upgrades. Use `claude update` out of band.
- **Homebrew casks in `system/darwin.nix` are darwin-wide and unconditional.**
  `onActivation.upgrade = true` means they upgrade on every switch, unlike the
  native-installer tools.
