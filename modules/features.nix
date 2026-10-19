# Name -> module path registry for the named features tiers/profiles can pull
# in (see the `tiers` binding and mkProfile in flake.nix: `minimal = []`,
# `full = builtins.attrNames features`). core/env aren't listed here: they're
# always-on, not selectable features.
#
# A value is either a bare path (the common case, no platform constraint) or
# an attrset { module = <path>; unsupported = [ "<system>" ... ]; optIn = bool; }.
# `unsupported` names systems a feature cannot build on: mkProfile drops it
# there and warns once at evaluation; `features.exclude` in a mkConfigs call
# silences the warning. `optIn = true` keeps a feature out of `full`, so only
# `features.extra` selects it.
{
  shell-tools = ./features/shell-tools.nix;
  lang-rust = ./features/lang-rust.nix;
  lang-node = ./features/lang-node.nix;
  lang-python = ./features/lang-python.nix;
  cloud = ./features/cloud.nix;
  claude = ./features/claude.nix;
  k8s = ./features/k8s.nix;
  tmux = ./features/tmux.nix;
  neovim = ./features/neovim.nix;
  git-tools = ./features/git-tools.nix;
  nix-tools = ./features/nix-tools.nix;
  data = ./features/data.nix;
  # qmk builds fine on x86_64-darwin under the pinned nixpkgs-25.05-darwin
  # input (verified directly: `nix build .#darwinConfigurations.full-darwin.pkgs.qmk`
  # succeeds on this repo's own x86_64-darwin machine) -- no `unsupported`
  # entry here.
  qmk = ./features/qmk.nix;
  # Opt-in: a weekly-moving input and a 64 to 103 MB index download per
  # update. No prebuilt index exists for x86_64-darwin (docs/adr/0002).
  nix-index = {
    module = ./features/nix-index.nix;
    unsupported = [ "x86_64-darwin" ];
    optIn = true;
  };
}
