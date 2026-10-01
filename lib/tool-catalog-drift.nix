# Bidirectional modules/tool-catalog.nix check (extracted from
# flake.nix, where it sat as five separate bindings alongside docs
# generation despite being a distinct concern): every installed package
# needs a catalog entry (or an explicit exclusion), and every catalog entry
# needs to actually correspond to something installed. Fails eval rather
# than letting the two drift silently.
#
# installedPackageNames is a parameter, not recomputed here: it depends on
# this repo's own already-built home/darwin/nixos configs (flake.nix's
# `self`), which only exist in flake.nix's own scope, and the nmt harness
# needs that same list independently for its own package-scrubbing logic
# (tests/nmt/harness.nix) -- so flake.nix keeps owning the one computation
# and threads it to both consumers, rather than this file recomputing its
# own copy.
{
  lib,
  toolCatalog,
  installedPackageNames,
}:
let
  catalogedNames = lib.concatMap (e: e.matches) toolCatalog.entries;
  uncatalogedInstalled = lib.subtractLists (
    catalogedNames ++ toolCatalog.infraExclude
  ) installedPackageNames;
  staleCatalogEntries = lib.subtractLists installedPackageNames catalogedNames;
in
lib.throwIf (uncatalogedInstalled != [ ])
  "modules/tool-catalog.nix is missing entries for installed packages: ${toString uncatalogedInstalled}"
  (
    lib.throwIf (staleCatalogEntries != [ ])
      "modules/tool-catalog.nix has entries for packages that aren't installed anywhere: ${toString staleCatalogEntries}"
      true
  )
