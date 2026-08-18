# Architecture

How nix-atelier actually thinks: the compositor model, the extension points,
and the checks that fail loudly rather than silently drifting. Written for a
human contributor; `CLAUDE.md` and `.claude/skills/nix-atelier/SKILL.md`
cover the same ground for an AI coding agent working in this repo, and stay
more current on file-level detail since they're read on every task.

## The shape of a config

A config is a plain list of Home Manager modules, assembled by one function:

```nix
mkProfile { tier, withGui, system, userData, featuresOverride }
```

Every config starts from the same always-on base, regardless of `tier`:

- `base.nix` -- shell init, git identity, SSH config, submodule overrides
- `env.nix` -- PATH and writable-prefix policy for Nix-managed runtimes
- `machine.nix` -- the `atelier.*` option namespace (AWS profile, native
  installers, private config repo clones, sops secrets, submodule remote
  overrides)
- `secrets-sops.nix` -- inert unless `atelier.sops.file` is set
- `caret` -- the shell prompt, always on, no opt-out (see "Decisions worth
  knowing" below)

On top of that, `tier` selects a feature set from `modules/features.nix`'s
registry: `minimal` is the empty list, `full` is every key in that registry
(`builtins.attrNames features`), which is why a new feature joins `full`
automatically and there's no second list to keep in sync. A `mkConfigs` call
can layer `features.extra` on top of a tier and drop items with
`features.exclude`, independent of which tier they came from.

`withGui` swaps in `gui-linux.nix` or `gui-darwin.nix` based on `system`.
darwin configs are always full tier and always GUI -- there's no
`minimal-darwin`, because a headless Mac isn't a real use case this
framework targets.

## The entry point: `lib.mkConfigs`

```nix
lib.mkConfigs { identity; configs; features; }
  -> { homeConfigurations; darwinConfigurations; nixosConfigurations; }
```

`configs` splits by kind (`configs.home`, `configs.darwin`, `configs.nixos`)
rather than one attrset with a `kind` field, so a field that only makes sense
for one kind (`tier` is home-only; `hardwareModule` is nixos-only) can't leak
into another and silently do nothing. The whole `identity`/`configs`/
`features` argument is validated through `lib.evalModules` with no
`freeformType` declared anywhere, so a misspelled field --
`configs.home.laptop.tierr`, say -- is a real "option does not exist" error
naming the option you probably meant, not a typo that quietly gets ignored.

Home and darwin configs are built by handing `mkProfile`'s module list to
`home-manager.lib.homeManagerConfiguration` or `nix-darwin.lib.darwinSystem`
respectively; the nixos kind calls `nixpkgs.lib.nixosSystem` directly. None
of this repo's own dogfooding matrix (this repo's `flake.nix` builds every
tier × GUI × architecture combination of its own placeholder identity) is
imposed on a real consumer -- `mkConfigs` itself does no matrix generation.
You name exactly the configs you want.

## Extension points

### Adding a package to an existing feature

Add it to the relevant `modules/features/*.nix`, then add a matching entry
to `modules/tool-catalog.nix` (package name -> one-line description). This
second step isn't optional bookkeeping: `modules/tool-catalog.nix` backs a
bidirectional eval-time check (see "Drift guards" below) that fails the
whole flake, not just a warning, if a package is installed with no catalog
entry, or catalogued but not actually installed anywhere.

### Adding a new feature

A feature is a Home Manager module file plus one line in
`modules/features.nix` mapping a name to that file's path. Nothing else
needs updating: `full` picks it up automatically (it's every registered
key), and `minimal` never includes it unless a consumer explicitly asks via
`features.extra`. If a feature genuinely doesn't build on some system (rare;
`modules/features.nix` supports an `unsupported = [ system ... ]` list per
entry), it's dropped from that system's module list and kept everywhere
else -- checked directly by one of this repo's own eval-time tests, not just
asserted in a comment.

### Adding a new config

This is entirely a consumer-side concern now, not something you edit in
this repo. A real machine's config lives in that machine's own `flake.nix`,
calling `lib.mkConfigs` with whatever `configs.home.<name>` /
`configs.darwin.<name>` / `configs.nixos.<name>` entries it wants. See
`templates/default/flake.nix` (what `nix flake init -t` scaffolds) and
`lib/mkConfigs.nix`'s own option descriptions for every field each kind
accepts. This repo's own `flake.nix` still builds a tier × GUI × arch
matrix of its own placeholder identity, but that's dogfooding `mkConfigs`
as its first real caller, not a list you're expected to add your own
machine to.

## Drift guards

Four checks fail evaluation outright (`throw`, not a warning) rather than
letting the codebase quietly drift out of sync with itself:

**Input pairing.** Home Manager and nix-darwin are each coupled to a
specific nixpkgs release. This repo carries two independent pairs (a rolling
one for Linux/WSL2 and Apple Silicon, a pinned one for the Intel Mac this
framework is still dogfooded on -- see `flake.nix`'s own comments for why
that pin exists). `checkReleasePair` (`lib/systems.nix`) compares release
strings and fails the whole flake on a mismatch, rather than the silent
warning Home Manager's own `enableNixpkgsReleaseCheck` gives by default,
which is easy to miss. Update both inputs of a pair together (`just update`
inside this repo takes no input argument, by design, so it can't update
only half a pair).

**Tool catalog drift.** `modules/tool-catalog.nix` maps every installed
package to a description, checked both directions: installed but
uncatalogued fails, catalogued but not installed also fails. This is the
most common surprise when touching a feature module -- see "Adding a
package" above.

**Unknown feature names.** A typo in `features.extra`/`features.exclude`
(or, before #122, `user.nix`'s equivalent fields) is looked up against
`modules/features.nix`'s registry and fails rather than silently doing
nothing. Tiers themselves can't have this problem: `full` is derived from
the registry, not hand-listed, so there's no second file that could
disagree with it.

**Schema validation.** One level up from the previous check, `mkConfigs`'s
own `lib.evalModules` schema catches a misspelled field anywhere in a
`mkConfigs` call itself, the same way any NixOS or Home Manager module
option does -- see "The entry point" above.

## The secrets story

Two tiers, deliberately not one:

- **Profile variables** known at build time (an AWS profile name, say) are
  plain `home.sessionVariables`, set via `atelier.aws.profile`. Left unset
  by default: a hardcoded default here risks a command silently hitting the
  wrong AWS account.
- **API keys and other real secrets** are never committed, not even
  encrypted, unless you opt in. The default path is a manually-maintained
  `~/.config/secrets/env` file (gitignored, sourced by every shell) --
  `secrets.env.example` at the repo root is the template. `atelier.sops`
  (set via a config's `extraConfig`) is an entirely optional upgrade to
  sops-nix: point `atelier.sops.file` at your own encrypted `secrets.yaml`
  and list the names you want decrypted in `atelier.sops.secrets`.
  `atelier.sops.file`'s presence is the on/off switch for the whole
  mechanism, no separate boolean, and it's deliberately a per-machine
  setting rather than one shared file, since the same secret name can carry
  a genuinely different value on a work machine than on a personal one. See
  `modules/secrets-sops.nix`.

## Decisions worth knowing

A few choices that are easy to trip over if you assume otherwise, since none
of them are written down anywhere outside code comments today:

- **`caret` is always the shell prompt, with no opt-out.** It isn't a
  feature you can exclude; it's part of the always-on base, the same tier
  as `base.nix` itself.
- **The `full` tier runs a vendor `curl | bash` install script on first
  activation**, unconditionally, for Claude Code (`modules/features/claude.nix`)
  and for any `atelier.nativeInstallers` you declare yourself. See
  `SECURITY.md`'s scope section for what that means and how to see or
  change exactly what runs.
- **`modules/features/tmux.nix` is the sole permitted owner of
  `programs.tmux`.** Nothing else in this codebase is allowed to touch tmux
  configuration, specifically because two features once disagreed on
  `historyLimit` and it was a real, hard-to-spot bug.
- **macOS is always `full` tier, no `minimal-darwin`.** A headless Mac
  isn't a configuration this framework targets; see "The shape of a
  config" above.

## Where to go next

- [CONTRIBUTING.md](CONTRIBUTING.md) -- what kind of change belongs in a PR
  here versus in your own flake.nix, and how to validate one locally
- [docs/profiles.md](docs/profiles.md) -- the generated reference for every
  tier/GUI/architecture combination this repo builds of itself
- [docs/bootstrap.md](docs/bootstrap.md) -- first-time setup, per target
- `CLAUDE.md` / `.claude/skills/nix-atelier/SKILL.md` -- the same material
  this document covers, kept current for an AI agent working in this repo
