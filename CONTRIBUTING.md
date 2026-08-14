# Contributing

## This repo is a consumable framework, not a fork-and-edit config

Two kinds of contributions make sense here, and it helps to know the difference before opening a PR.

### Consume it for personal preferences

Tool choices, dotfile content, prompt theming, personal modules, your own identity: these belong in your own flake.nix, calling `lib.mkConfigs`, not in a PR here. PRs that change personal preferences (e.g. "use neovim instead of vim", "add my preferred aliases") won't be accepted. See [docs/profiles.md](docs/profiles.md) for the `features.extra`/`features.exclude`/`features.extraModulePaths` escape hatches, and [examples/private-config/](examples/private-config/) for a worked example of machine-specific customization living entirely outside this repo.

### PRs welcome for framework improvements

Improvements to the *framework itself* benefit every adopter and are welcome:

- Bug fixes in activation scripts, module composition, or CI
- Improvements to `mkProfile` (`flake.nix`) or `lib/mkConfigs.nix`'s schema and builders
- New module *patterns* (not personal tool choices)
- Documentation fixes and additions
- CI/lint pipeline improvements

If you're unsure whether something is framework or personal preference, open an issue first.

______________________________________________________________________

## Adapting for your own setup

1. `nix flake init -t github:cdprice02/nix-atelier` in a new directory
2. Fill in `flake.nix`: your identity, and at least one config
3. `nix flake check`
4. Apply: `nix run home-manager -- switch --flake .#<name>` (or `sudo darwin-rebuild switch` for a darwin config)

See [docs/bootstrap.md](docs/bootstrap.md) for the full first-time setup checklist, [templates/default/README.md](templates/default/flake.nix) for what the scaffolded `flake.nix` looks like, and [docs/profiles.md](docs/profiles.md) for the tier/gui/arch axes and the `features.extra`/`features.exclude`/`features.extraModulePaths` customization hooks.

Working inside a clone of this repo itself, to submit a framework improvement, is different: see "Local validation" below, and note this repo's own `flake.nix` builds placeholder-identity configs to prove `lib.mkConfigs` works, not a real machine's config.

______________________________________________________________________

## Local validation

Before opening a PR, run:

```sh
just eval-all                 # fast: every profile's drvPath, no building
just check                    # fuller: nix flake check, formatting included
nix fmt                       # or `just fmt`: auto-fixes (nixfmt-rfc-style, statix, deadnix, mdformat)
just precommit                # trailing whitespace, secrets scan, treefmt
```

`just eval-all` shells out to `jq`; have it installed (or run it inside `nix develop`, which provides it).

`just --list` only shows the everyday recipes; a few CI-internal ones (profile listing, per-profile build) are prefixed `_` and hidden from the default list by design, but still runnable and inspectable: `just _build-linux full`, `just --show _build-linux`.

CI runs these same recipes (see `.github/workflows/check.yml`) plus full builds for every profile, but full builds only run on push to `main` or manual dispatch, not on every PR (see `check.yml`'s comments for why). So a green `just eval-all` + `just check` locally is close to, but not identical to, full CI coverage.

## Verifying large refactors

For a change that's supposed to be behavior-preserving (a mechanism reorganization, not a functional change), `nix eval`'s output is a stronger check than "does it still build": capture every profile's `drvPath` before the change (`just eval-all` prints them), make the change, capture again, and diff. Any profile whose `drvPath` changed needs an explanation: either it's a real, intended behavior change, or the refactor wasn't actually behavior-preserving. This isn't a blanket CI gate (ordinary commits are *supposed* to change `drvPath`s), just a manual technique worth reaching for on big refactors specifically. A disposable `git worktree add <tmp-dir> <pre-change-commit>` is safer than `git stash` for getting a clean baseline when there's a lot of already-pending uncommitted work.

______________________________________________________________________

## PR standards

- One concern per PR
- Conventional commit message: `fix:`, `feat:`, `docs:`, `refactor:`, `chore:`
- All CI checks green before requesting review
- Update docs if the change affects bootstrap, profile selection, or module composition

______________________________________________________________________

## Repository secrets

Only one, and only for the weekly `flake.lock` automation:

| Secret               | Why                                                                                                                                            |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `FLAKE_UPDATE_TOKEN` | Fine-grained PAT, this repo only, **Contents: read/write** + **Pull requests: read/write**. Used by `.github/workflows/update-flake-lock.yml`. |

GitHub does not raise workflow-triggering events for actions taken with the
default `GITHUB_TOKEN`, so a PR opened with it receives **no CI at all**. Without
this secret the weekly lock-update PR would look reviewable while having been
tested by nothing. The workflow falls back to `GITHUB_TOKEN` when the secret is
absent (so forks still work) and says so in the PR body; if you see a lock PR
with no checks, that is why, and it needs a push or a close/reopen before it is
safe to merge.

Nothing else in CI needs a secret; `GITHUB_TOKEN` covers the rest.

## Reporting issues

For framework bugs or feature ideas, open an issue using the appropriate template. Personal config questions are better suited for a fork or a Nix community forum like [discourse.nixos.org](https://discourse.nixos.org).
