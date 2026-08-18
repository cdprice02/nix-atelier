# private-config example

A worked, generic example of the pattern the framework expects for
machine-specific, non-public data: identity overrides, packages too niche
for a shared feature, and real secrets. None of it belongs in the public
`nix-atelier` repo, and none of it is a Nix module the framework imports on
its own: every file here is wired in explicitly, per machine, from that
machine's own `lib.mkConfigs` call (see `templates/default/flake.nix` for the
entry point this plugs into).

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

Each `machines/*.nix` file is a home-manager module fragment. `laptop.nix`
and `build-server.nix` are plain modules; `workstation.nix` is a module
*factory* (a function of `{ hmCompatPath }` that returns the module), since
it needs nix-atelier's `hm-compat.nix` helper for a forced git-identity
override and that path has to be threaded in from the consuming flake rather
than assumed. Each file demonstrates one *kind* of customization:

- **`workstation.nix`**: overrides `base.nix`'s git identity for this one
  machine (the pattern a work machine typically needs), and installs a
  package that isn't worth a public feature.
- **`laptop.nix`**: sets an environment variable and a `PATH` entry that
  only make sense on this one machine.
- **`build-server.nix`**: a headless machine's tier (`minimal`, typically)
  is set in that machine's own `configs.home.<name>.tier`, not here; this
  file only adds the one extra package that machine's job needs.

## Wiring it into nix-atelier

In the target machine's `flake.nix`, a config's own `extraConfig` is the
place to both set `atelier.*` options (see Secrets below) and `imports` a
private machine module -- there is no repo-wide `extraModulePaths` shared
across every config `lib.mkConfigs` produces, since a config's own
`extraConfig` merges only into that one config:

```nix
configs.home.<name>.extraConfig = {
  imports = [
    (import /absolute/path/to/your-private-repo/machines/workstation.nix {
      hmCompatPath = "${nix-atelier}/modules/lib/hm-compat.nix";
    })
  ];
};
```

A machine can layer in more than one module the same way, just by adding
more entries to `imports`. Resolving an absolute path outside the flake's
own source needs `--impure` on that machine's own `home-manager switch` /
`darwin-rebuild switch` -- not on `mkConfigs` itself, and not on nix-atelier's
own `flake.nix`, which never touches this mechanism.

## Secrets

`secrets/secrets.yaml.example` and `.sops.yaml.example` show the shape of a
real private secrets file; see the root repo's own `docs/bootstrap.md` for
the actual `age-keygen` / `sops` steps to create one for real. Once you have
one, wire it in the same way as a machine module, via that machine's own
config's `extraConfig`:

```nix
configs.home.<name>.extraConfig.atelier.sops = {
  secrets = ["GITHUB_PERSONAL_ACCESS_TOKEN" "MY_SERVICE_PAT"];
  file = "/absolute/path/to/your-private-repo/secrets/workstation.yaml";
};
```

One file per machine, not one shared file: the same service can need a
different token on a different machine, and `secrets-sops.nix` is built
around that: each machine's own config points its own `atelier.sops.file` at
its own file, so the same key *name* can carry a different real value per
machine.
