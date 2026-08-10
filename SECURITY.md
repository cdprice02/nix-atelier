# Security Policy

## Supported versions

Only `main` is supported. This is a personal configuration, not a versioned
library: apply fixes by pulling latest, not by requesting a backport.

## Reporting a vulnerability

Use GitHub's
[private vulnerability reporting](https://github.com/cdprice02/nix-config/security/advisories/new),
which is visible only to the maintainer. If you would rather not use GitHub,
use any contact listed on the maintainer's
[profile](https://github.com/cdprice02).

Do not open a public issue for a security report.

This is a single-maintainer project, so reports are reviewed and answered as
promptly as is practical rather than to a fixed SLA.

## Scope

What's relevant to report here:

- A way for a fork's `just switch` / `just check` to execute attacker-controlled
  code beyond what's already inherent to Nix (arbitrary flake evaluation is a
  known, accepted risk of using flakes at all; this is about anything beyond
  that baseline).
- A flaw in the activation scripts (`sshKey`, `submoduleOverrides`, the
  native-installer hooks in `features/claude.nix`) that could leak a secret,
  overwrite unrelated files, or run with unintended privilege.
- A sops/age misconfiguration that could expose `secrets/secrets.yaml`'s
  plaintext values to an unintended recipient.

What's out of scope, by design rather than oversight:

- `user.nix`, `~/.certs/corporate.pem`, and `~/.config/secrets/env` are
  gitignored and never committed; they hold real identity and secrets values
  on a machine but are not part of this repository's history.
- `secrets/secrets.yaml` is committed, but every value in it is encrypted with
  [sops](https://github.com/getsops/sops) to the recipient declared in
  `.sops.yaml`. Its presence in git history is expected; being unable to
  decrypt it without the corresponding age key is the point.
- `gitleaks` (`.github/workflows/security.yml`) already scans every push and
  PR for accidentally committed plaintext secrets. A finding there is CI
  failing loudly, not something to report privately.
