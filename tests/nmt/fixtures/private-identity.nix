# Fixture for composition.nix's extraModulePaths test: stands in for a real
# private module (see examples/private-config/machines/*.nix for the shape
# this mirrors), so the test exercises the actual force-override mechanism
# private modules rely on rather than a synthetic shortcut. Lives inside the
# repo's own tree (not a real "private" path) purely because a test fixture
# has to be something the harness can resolve deterministically; production
# extraModulePaths entries point outside the repo instead.
{
  lib,
  options,
  ...
}:
let
  compat = import ../../../modules/lib/hm-compat.nix { inherit lib options; };
in
{
  programs.git = compat.gitIdentity {
    name = "Fixture Override";
    email = "fixture-override@example.com";
    force = true;
  };
}
