# Contributing

## This repo is a personal config — and a reusable framework

Two kinds of contributions make sense here, and it helps to know the difference before opening a PR.

### Fork for personal preferences

Tool choices, dotfile content, prompt theming, personal modules, your own username — these belong in your fork. PRs that change personal preferences (e.g. "use neovim instead of vim", "add my preferred aliases") won't be accepted here, but forks are actively encouraged. See [docs/profiles.md](docs/profiles.md) for how to add your own profiles without touching shared code.

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
just check                    # nix flake check --impure
pre-commit run --all-files    # alejandra, markdownlint, trailing whitespace, secrets scan
```

Both must pass. CI additionally runs `statix` and `deadnix` (Nix linters not in pre-commit) and builds all 16 Linux profiles and all Darwin profiles — so a green pre-commit run does not guarantee a green CI run.

---

## PR standards

- One concern per PR
- Conventional commit message: `fix:`, `feat:`, `docs:`, `refactor:`, `chore:`
- All CI checks green before requesting review
- Update docs if the change affects bootstrap, profile selection, or module composition

---

## Reporting issues

For framework bugs or feature ideas, open an issue using the appropriate template. Personal config questions are better suited for a fork or a Nix community forum like [discourse.nixos.org](https://discourse.nixos.org).
