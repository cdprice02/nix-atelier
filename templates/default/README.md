# My nix-atelier config

Scaffolded by `nix flake init -t github:cdprice02/nix-atelier`.

```text
flake.nix              # identity + one entry per machine
machines/work.nix      # settings only the `work` machine gets
secrets/*.yaml.example # the shape of a machine's sops secrets file
.sops.yaml.example     # who can decrypt them
```

## Next steps

1. Edit `flake.nix`: fill in your real `identity`, then keep, rename or
   delete the example configs. Copy `machines/work.nix` for another machine
   that needs its own settings.

2. `git init && git add -A`: a flake only sees files git tracks.

3. `nix flake check` to validate: a misspelled field is a real error, not a
   silent no-op.

4. Apply it with [nh](https://github.com/nix-community/nh), which shows the
   package and closure-size diff before activating (`-n` stops after the
   diff). nix-atelier installs nh, so only the first switch differs:

   - Home Manager: `nix run nixpkgs#nh -- home switch -c <name> -b bk .`
     the first time, then `nh home switch -c <name> .`. nh needs
     `experimental-features = nix-command flakes` in `nix.conf`.
   - nix-darwin: the first switch has to be
     `sudo nix --extra-experimental-features "nix-command flakes" run nix-darwin -- switch --flake .#<name>`,
     because flakes aren't enabled for root until nix-darwin manages
     `/etc/nix/nix.conf`. After that, `nh darwin switch -H <name> .`

## Secrets

Optional: without them, nix-atelier reads `~/.config/secrets/env` instead.

1. `age-keygen -o ~/.config/sops/age/keys.txt` prints your public key.
2. Rename `.sops.yaml.example` to `.sops.yaml` and put that key in it.
3. `sops secrets/work.yaml` and add the keys `secrets/work.yaml.example`
   lists.
4. Uncomment `atelier.sops` in the `work` config.

## Where to look next

- [nix-atelier's `lib/mkConfigs.nix`](https://github.com/cdprice02/nix-atelier/blob/main/lib/mkConfigs.nix)
  documents every field `configs.home`/`.darwin`/`.nixos` accepts.
- [`modules/features.nix`](https://github.com/cdprice02/nix-atelier/blob/main/modules/features.nix)
  lists every named feature you can add via `features.extra`.
- [`modules/machine.nix`](https://github.com/cdprice02/nix-atelier/blob/main/modules/machine.nix)
  documents `atelier.*` options (AWS profile, native installers, private
  config repo clones, sops secrets): set any of them per-config via
  `configs.home.<name>.extraConfig`.
- [`docs/bootstrap.md`](https://github.com/cdprice02/nix-atelier/blob/main/docs/bootstrap.md)
  covers installing Nix and per-platform setup.
