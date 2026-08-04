# Contributing

## This repo is a personal config, and a reusable framework

Two kinds of contributions make sense here, and it helps to know the difference before opening a PR.

### Fork for personal preferences

Tool choices, dotfile content, prompt theming, personal modules, your own username: these belong in your fork. PRs that change personal preferences (e.g. "use neovim instead of vim", "add my preferred aliases") won't be accepted here, but forks are actively encouraged. See [docs/profiles.md](docs/profiles.md) for how to add your own profiles without touching shared code.

### PRs welcome for framework improvements

Improvements to the *framework itself* benefit every adopter and are welcome:

- Bug fixes in activation scripts, module composition, or CI
- Improvements to `mkProfile`, `mkHomeConfig`, `mkDarwinConfig` helpers in `flake.nix`
- New module *patterns* (not personal tool choices)
- Documentation fixes and additions
- CI/lint pipeline improvements

If you're unsure whether something is framework or personal preference, open an issue first.

---

## Adapting for your own setup

1. Fork this repo
2. Copy the identity template: `cp user.nix.example user.nix`
3. Fill in `user.nix` with your username, name, and email
4. Apply: `nix run home-manager -- switch --flake ~/.nix-config#personal --impure`

See [docs/bootstrap.md](docs/bootstrap.md) for the full first-time setup checklist and [docs/profiles.md](docs/profiles.md) for how to add or customize profiles.

---

## Local validation

Before opening a PR, run:

```sh
just eval-all                 # fast: every profile's drvPath, no building
just check                    # fuller: nix flake check --impure
just lint-all                 # alejandra, statix, deadnix, markdownlint
pre-commit run --all-files    # trailing whitespace, secrets scan (+ the two lints above)
```

`just --list` only shows the everyday recipes; a few CI-internal ones (profile listing, per-profile build, individual lints) are prefixed `_` and hidden from the default list by design, but still runnable and inspectable: `just _build-linux personal`, `just --show _build-linux`.

CI runs these same recipes (see `.github/workflows/check.yml`) plus full builds for every profile, but full builds only run on push to `main` or manual dispatch, not on every PR (see `check.yml`'s comments for why). So a green `just eval-all` + `just lint-all` locally is close to, but not identical to, full CI coverage.

## Verifying large refactors

For a change that's supposed to be behavior-preserving (a mechanism reorganization, not a functional change), `nix eval`'s output is a stronger check than "does it still build": capture every profile's `drvPath` before the change (`just eval-all` prints them), make the change, capture again, and diff. Any profile whose `drvPath` changed needs an explanation: either it's a real, intended behavior change, or the refactor wasn't actually behavior-preserving. This isn't a blanket CI gate (ordinary commits are *supposed* to change `drvPath`s), just a manual technique worth reaching for on big refactors specifically. A disposable `git worktree add <tmp-dir> <pre-change-commit>` is safer than `git stash` for getting a clean baseline when there's a lot of already-pending uncommitted work.

---

## PR standards

- One concern per PR
- Conventional commit message: `fix:`, `feat:`, `docs:`, `refactor:`, `chore:`
- All CI checks green before requesting review
- Update docs if the change affects bootstrap, profile selection, or module composition

---

## Repository secrets

Only one, and only for the weekly `flake.lock` automation:

| Secret | Why |
|--------|-----|
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
