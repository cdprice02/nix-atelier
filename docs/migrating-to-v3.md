# Migrating from a v1/v2 fork to v3

If you forked nix-atelier before v3.0.0 and have your own `user.nix`, the
fork-and-edit model that checkout was built around no longer exists. v3
replaces it entirely with a consumable library: your own `flake.nix`, in
your own repo, pins `nix-atelier` as a flake input and calls
`nix-atelier.lib.mkConfigs` directly. There is no fork to keep in sync with
upstream anymore, because there's no fork.

## The shape of the change

Old (a fork of this repo, `user.nix` filled in):

```sh
git clone your-fork nix-atelier && cd nix-atelier
cp user.nix.example user.nix && $EDITOR user.nix
home-manager switch --flake .#full --impure
```

New (a separate repo you own, no checkout of this repo needed at all):

```sh
mkdir my-config && cd my-config
nix flake init -t github:cdprice02/nix-atelier
$EDITOR flake.nix
nix flake check
home-manager switch --flake .#<name>       # or sudo darwin-rebuild switch
```

## Where each `user.nix` field goes now

| Old `user.nix` field                  | New location                                                                     |
| ------------------------------------- | -------------------------------------------------------------------------------- |
| `username`, `name`, `email`, `github` | `identity` in your own `mkConfigs` call, same shape                              |
| `profile`                             | a `configs.home.<name>` / `configs.darwin.<name>` entry, named whatever you like |
| `extraFeatures`                       | `features.extra`                                                                 |
| `excludeFeatures`                     | `features.exclude`                                                               |
| `extraModulePaths`                    | `features.extraModulePaths`                                                      |
| `aws.profile`                         | `configs.<kind>.<name>.extraConfig.atelier.aws.profile`                          |
| `nativeInstallers`                    | `configs.<kind>.<name>.extraConfig.atelier.nativeInstallers`                     |
| `configRepos`                         | `configs.<kind>.<name>.extraConfig.atelier.configRepos`                          |
| `secrets` / `sopsFile`                | `configs.<kind>.<name>.extraConfig.atelier.sops.{secrets,file}`                  |
| `submodules`                          | `configs.<kind>.<name>.extraConfig.atelier.submodules`                           |

`features.*` is shared across every config a single `mkConfigs` call
produces; `atelier.*` (everything under `extraConfig`) is set per config, so
two machines in the same call can carry different secrets files or AWS
profiles.

## What to actually do

1. Create a new, separate repo for your own `flake.nix` (or reuse a private
   config repo you already have going).
2. `nix flake init -t github:cdprice02/nix-atelier` in it.
3. Fill in `identity` from your old `user.nix`'s top-level fields.
4. Add one `configs.home.<name>` or `configs.darwin.<name>` entry per
   machine, translating any field you had set using the table above.
5. If you had private modules wired in via `extraModulePaths`, most still
   work unmodified. One exception: a private module that resolved this
   repo's own `modules/lib/hm-compat.nix` via a hardcoded `~/.nix-atelier`
   path needs to resolve it through the flake input instead. See
   `examples/private-config/machines/workstation.nix` for the pattern (a
   module factory taking `hmCompatPath`, resolved by the caller from
   `"${nix-atelier}/modules/lib/hm-compat.nix"`).
6. Delete your fork. There's nothing left in it to keep in sync.
7. `nix flake check`, then apply as usual.

See [templates/default/flake.nix](../templates/default/flake.nix) for the
scaffold, [lib/mkConfigs.nix](../lib/mkConfigs.nix) for every field each
config kind accepts, and
[examples/private-config/](../examples/private-config/) for a worked
machine-module example.
