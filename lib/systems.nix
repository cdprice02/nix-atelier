# Everything about "which of the two release pairs does this system use, and
# what are the resolved tools for it": one cohesive unit instead of the same
# x86_64-darwin-vs-rolling dispatch spread across half a dozen separate
# bindings. flake.nix's own (still impure, pre-#122) config construction and
# lib/mkConfigs.nix both import this rather than each carrying their own copy.
{
  nixpkgs,
  nixpkgs-darwin,
  home-manager,
  home-manager-darwin,
  nix-darwin,
  nix-darwin-x86,
  rust-overlay,
}:
let
  inherit (nixpkgs) lib;

  allSystems = [
    "x86_64-linux"
    "aarch64-linux"
    "x86_64-darwin"
    "aarch64-darwin"
  ];
  linuxSystems = [
    "x86_64-linux"
    "aarch64-linux"
  ];
  darwinSystems = lib.subtractLists linuxSystems allSystems;

  isLinux = s: builtins.elem s linuxSystems;
  # Only x86_64-darwin uses the pinned 25.05 darwin inputs (see flake.nix's
  # nixpkgs-darwin input comment for why). aarch64-darwin rides the rolling
  # inputs, same as Linux.
  isX86Darwin = s: s == "x86_64-darwin";

  pkgsConfig = {
    allowUnfree = true;
  };

  mkPkgs =
    system:
    import nixpkgs {
      inherit system;
      config = pkgsConfig;
      overlays = [ rust-overlay.overlays.default ];
    };
  mkPkgsDarwin =
    system:
    import nixpkgs-darwin {
      inherit system;
      config = pkgsConfig;
      overlays = [ rust-overlay.overlays.default ];
    };
  # Right package set for any system: pinned nixpkgs-darwin for x86_64-darwin,
  # rolling nixpkgs for everything else (Linux + aarch64-darwin).
  pkgsFor = system: if isX86Darwin system then mkPkgsDarwin system else mkPkgs system;

  # Home Manager's module code is coupled to its nixpkgs release: a mismatched
  # pair evaluates but emits deprecation warnings and can silently generate
  # wrong config (HM itself only warns, via home.enableNixpkgsReleaseCheck).
  # Fail evaluation instead, so drift can't be ignored.
  hmRelease = hm: (builtins.fromJSON (builtins.readFile (hm + "/release.json"))).release;
  checkReleasePair =
    label: hm: npkgs:
    let
      hmVer = hmRelease hm;
      npkgsVer = npkgs.lib.trivial.release;
    in
    lib.throwIf (hmVer != npkgsVer) ''
      ${label}: home-manager (${hmVer}) and nixpkgs (${npkgsVer}) releases disagree.

      Home Manager modules are coupled to their nixpkgs release; a mismatched
      pair produces deprecation warnings and can generate incorrect config.

      Fix: update both inputs of this pair together: `just update`.
    '' true;

  linuxPairOk = checkReleasePair "rolling (Linux/WSL2 + aarch64-darwin)" home-manager nixpkgs;
  darwinPairOk = checkReleasePair "x86_64-darwin (pinned)" home-manager-darwin nixpkgs-darwin;
  pairOkFor = system: if isX86Darwin system then darwinPairOk else linuxPairOk;

  hmLibFor = system: if isX86Darwin system then home-manager-darwin.lib else home-manager.lib;
  hmDarwinModuleFor =
    system:
    if isX86Darwin system then
      home-manager-darwin.darwinModules.home-manager
    else
      home-manager.darwinModules.home-manager;
  darwinLibFor = system: if isX86Darwin system then nix-darwin-x86 else nix-darwin;

  # The one, single definition of this repo's homeConfigurations naming
  # scheme (#118): flake.nix's own matrix construction and docs-gen.nix's
  # profile table both call this directly now, instead of docs-gen.nix
  # carrying a second copy reconciled by an eval-time throw. A renamed
  # scheme can no longer make the two disagree; there is only one function.
  mkHomeConfigName =
    tierName: withGui: arch:
    tierName
    + (lib.optionalString withGui "-gui")
    + (lib.optionalString (arch == "aarch64-linux") "-aarch64");
in
{
  inherit
    allSystems
    linuxSystems
    darwinSystems
    isLinux
    isX86Darwin
    pkgsConfig
    pkgsFor
    linuxPairOk
    darwinPairOk
    pairOkFor
    hmLibFor
    hmDarwinModuleFor
    darwinLibFor
    mkHomeConfigName
    ;

  # NixOS only ever uses the rolling trio: there is no pinned-x86_64-darwin-
  # style split for it (no NixOS hardware constraint drives one).
  nixosHmModule = home-manager.nixosModules.home-manager;
}
