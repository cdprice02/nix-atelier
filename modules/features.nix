# Name -> module path registry for the named features tiers/profiles can pull
# in (see profiles.nix and mkProfile in flake.nix). core/env aren't listed
# here: they're always-on, not selectable features.
#
# A value is either a bare path (the common case, no platform constraint) or
# an attrset { module = <path>; unsupported = [ "<system>" ... ]; } for a
# feature that cannot build on some system this flake targets. mkProfile
# drops an unsupported feature on that system and warns once at evaluation;
# `excludeFeatures` in user.nix silences the warning.
{
  shell-tools = ./features/shell-tools.nix;
  lang-rust = ./features/lang-rust.nix;
  lang-node = ./features/lang-node.nix;
  lang-python = ./features/lang-python.nix;
  cloud = ./features/cloud.nix;
  ai = ./features/ai.nix;
  k8s = ./features/k8s.nix;
  dev-tools = ./features/dev-tools.nix;
  ops = ./features/ops.nix;
}
