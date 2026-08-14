# Name -> module path registry for the named features tiers/profiles can pull
# in (see the `tiers` binding and mkProfile in flake.nix: `minimal = []`,
# `full = builtins.attrNames features`). core/env aren't listed here: they're
# always-on, not selectable features.
#
# A value is either a bare path (the common case, no platform constraint) or
# an attrset { module = <path>; unsupported = [ "<system>" ... ]; } for a
# feature that cannot build on some system this flake targets. mkProfile
# drops an unsupported feature on that system and warns once at evaluation;
# `features.exclude` in a mkConfigs call silences the warning.
{
  shell-tools = ./features/shell-tools.nix;
  lang-rust = ./features/lang-rust.nix;
  lang-node = ./features/lang-node.nix;
  lang-python = ./features/lang-python.nix;
  cloud = ./features/cloud.nix;
  claude = ./features/claude.nix;
  copilot = ./features/copilot.nix;
  k8s = ./features/k8s.nix;
  tmux = ./features/tmux.nix;
  git-tools = ./features/git-tools.nix;
  nix-tools = ./features/nix-tools.nix;
  data = ./features/data.nix;
  # qmk builds fine on x86_64-darwin under the pinned nixpkgs-25.05-darwin
  # input (verified directly: `nix build .#darwinConfigurations.full-darwin.pkgs.qmk`
  # succeeds on this repo's own x86_64-darwin machine) -- no `unsupported`
  # entry here. tool-catalog.nix previously claimed otherwise; that claim
  # was checked against `meta.available` only, which doesn't account for a
  # transitively broken dependency and also doesn't match this repo's own
  # CI, which has built qmk into the x86_64-darwin full tier all along.
  qmk = ./features/qmk.nix;
}
