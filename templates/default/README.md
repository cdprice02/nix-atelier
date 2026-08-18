# My nix-atelier config

Scaffolded by `nix flake init -t github:cdprice02/nix-atelier`.

## Next steps

1. Edit `flake.nix`: fill in your real `identity` and at least one entry
   under `configs`.
2. `nix flake check` to validate: a misspelled field is a real error, not a
   silent no-op.
3. Apply it:
   - Home Manager: `nix run home-manager -- switch --flake .#<name>`
   - nix-darwin: `sudo darwin-rebuild switch --flake .#<name>`

## Where to look next

- [nix-atelier's `lib/mkConfigs.nix`](https://github.com/cdprice02/nix-atelier/blob/main/lib/mkConfigs.nix)
  documents every field `configs.home`/`.darwin`/`.nixos` accepts.
- [`modules/features.nix`](https://github.com/cdprice02/nix-atelier/blob/main/modules/features.nix)
  lists every named feature you can add via `features.extra`.
- [`modules/machine.nix`](https://github.com/cdprice02/nix-atelier/blob/main/modules/machine.nix)
  documents `atelier.*` options (AWS profile, native installers, private
  config repo clones, sops secrets): set any of them per-config via
  `configs.home.<name>.extraConfig`.
