# Security Policy

## Supported versions

Only `main` is supported. Tagged releases exist to mark meaningful
milestones, not to carry a backport policy: apply fixes by bumping your
`nix-atelier` flake input to latest, not by requesting a patch against an
older tag.

## Reporting a vulnerability

Use GitHub's
[private vulnerability reporting](https://github.com/cdprice02/nix-atelier/security/advisories/new),
which is visible only to the maintainer. If you would rather not use GitHub,
use any contact listed on the maintainer's
[profile](https://github.com/cdprice02).

Do not open a public issue for a security report.

This is a single-maintainer project, so reports are reviewed and answered as
promptly as is practical rather than to a fixed SLA.

## Scope

What's relevant to report here:

- A way for a consumer's `just switch` / `just check`, or their own
  `home-manager switch` / `darwin-rebuild switch` against a `lib.mkConfigs`
  call, to execute attacker-controlled code beyond what's already inherent to
  Nix (arbitrary flake evaluation is a known, accepted risk of using flakes at
  all; this is about anything beyond that baseline).
- A flaw in the activation scripts (`sshKey`, `submoduleOverrides`, the
  native-installer hooks in `features/claude.nix`) that could leak a secret,
  overwrite unrelated files, or run with unintended privilege.
- Note on the native-installer hooks specifically: the `full` tier runs a
  first-party-vendor-hosted `curl | bash` script (`claude.ai/install.sh`)
  unconditionally on first activation, and does the same for any
  `atelier.nativeInstallers` entry a consumer declares. This is a
  deliberate design choice (see `modules/lib/native-installer.nix`'s own
  comments for why), disclosed here and in `docs/bootstrap.md` rather than
  something to report on its own; a flaw in *how* it's invoked (the
  previous bullet) is still in scope.
- A flaw in `modules/secrets-sops.nix` that could expose a decrypted secret
  to an unintended recipient, or resolve to the wrong `sopsFile`.

What's out of scope, by design rather than oversight:

- A consumer's own real identity and secrets values live in their own
  flake.nix (`lib.mkConfigs`'s `identity` argument) and
  `~/.config/secrets/env` (gitignored, never committed); neither is part of
  this repository's history. The same is true of any real, private
  `secrets.yaml` a consumer points `atelier.sops.file` at; this repo's own
  `secrets/secrets.yaml.example` and `.sops.yaml` are placeholder-only and
  carry no real ciphertext or real recipient.
- `gitleaks` (`.github/workflows/security.yml`) already scans every push and
  PR for accidentally committed plaintext secrets. A finding there is CI
  failing loudly, not something to report privately.
