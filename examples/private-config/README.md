# private-config example

A worked, generic example of the pattern the framework expects for
machine-specific, non-public data: identity overrides, packages too niche
for a shared feature, and real secrets. None of it belongs in the public
`nix-atelier` repo, and none of it is a Nix module the framework imports on
its own — every file here is wired in explicitly, per machine, from that
machine's own `user.nix`.

This directory is not meant to be used as-is. Copy it out to your own
private repo, rename the machine files to match your own machines, delete
the ones you don't need, and fill in real values. It exists to show the
shape, not to be cloned and run.

## Layout

```text
machines/
  workstation.nix     # identity override + a couple of extra packages
  laptop.nix           # a machine-specific environment variable and PATH entry
  build-server.nix     # a headless machine's own small, private package
secrets/
  secrets.yaml.example  # placeholder names only, not sops-encrypted
.sops.yaml.example      # placeholder recipient
```

Each `machines/*.nix` file is a plain home-manager module fragment — no
special shape required beyond being a valid module. Each demonstrates one
*kind* of customization:

- **`workstation.nix`** — overrides `base.nix`'s git identity for this one
  machine (the pattern a work machine typically needs), and installs a
  package that isn't worth a public feature.
- **`laptop.nix`** — sets an environment variable and a `PATH` entry that
  only make sense on this one machine.
- **`build-server.nix`** — a headless machine's tier (`minimal`, typically)
  is set in *that machine's own* `user.nix`, not here; this file only adds
  the one extra package that machine's job needs.

## Wiring it into nix-atelier

In the target machine's `user.nix`:

```nix
extraModulePaths = ["/absolute/path/to/your-private-repo/machines/workstation.nix"];
```

`extraModulePaths` takes a list — a machine can layer in more than one file
if it genuinely needs to. Requires `--impure`, which every `home-manager
switch` / `darwin-rebuild switch` already needs for `user.nix` itself.

## Secrets

`secrets/secrets.yaml.example` and `.sops.yaml.example` show the shape of a
real private secrets file — see the root repo's own `docs/bootstrap.md` for
the actual `age-keygen` / `sops` steps to create one for real. Once you have
one, wire it in the same way as a machine module, via that machine's
`user.nix`:

```nix
secrets  = ["GITHUB_PERSONAL_ACCESS_TOKEN" "MY_SERVICE_PAT"];
sopsFile = "/absolute/path/to/your-private-repo/secrets/workstation.yaml";
```

One file per machine, not one shared file: the same service can need a
different token on a different machine, and `secrets-sops.nix` is built
around that — each machine's `user.nix` points its own `sopsFile` at its
own file, so the same key *name* can carry a different real value per
machine.
