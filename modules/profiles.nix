# Tier -> feature-name list (resolved against features.nix's registry by
# mkProfile in flake.nix). Only the tier-specific additions: core/env are a
# separate, always-on prefix mkProfile adds unconditionally.
{
  minimal = [];
  dev = ["shell-tools" "lang-rust" "lang-node" "lang-python" "cloud" "ai" "k8s" "dev-tools"];
  server = ["shell-tools" "ops"];
}
