# The nmt test harness: builds the scrubbed, build-free module list and nmt
# test-runner wiring flake.nix's `checks` output evaluates every nmt
# instance (default, GUI, composition) through. Moved out of flake.nix
# itself (see #117) so the production entry point isn't three-quarters test
# infrastructure; imported from there the same way tests/nmt/*.nix already
# are for their own assertions.
{
  self,
  nixpkgs,
  home-manager,
  home-manager-darwin,
  nmt,
  isX86Darwin,
  pkgsFor,
  mkUser,
  mkProfile,
  installedPackageNames,
}:
let
  # ── Test harness (nmt) ───────────────────────────────────────────────────
  # nmt (home-manager's own module test framework) evaluates a home-manager
  # configuration with every derivation's outPath replaced by a
  # "@package-name@" placeholder, then runs bash assertions against the
  # rendered home-files tree. It never builds a real package, so it runs on
  # every system this flake targets, including x86_64-darwin, where `checks`
  # otherwise has almost nothing to say (see docs-drift's own comment below).
  nmtSrc = nmt;

  # user.nix.example, not a real user.nix: tests must be identity-independent,
  # not a description of whichever machine happens to be evaluating them.
  testUser = mkUser (import (self + /user.nix.example));

  # Replaces a single derivation's outPath with "@name@" (its own name, not
  # the caller's attribute name, so e.g. buildPackages.gettext and
  # top-level gettext scrub identically). Reached only for the specific
  # top-level packages named below, never applied to the rest of pkgs.
  scrubDerivation =
    name: value:
    value
    // {
      outPath = "@${value.name or name}@";
      outputSpecified = true;
    };

  # Real, unscrubbed pkgs stay the default; only the specific packages this
  # repo actually installs (installedPackageNames, below -- the same list
  # the docs/tool-catalog bidirectional check validates against) get
  # scrubbed. This is the inverse of scrubbing everything and clawing back
  # exceptions, and it is deliberate, not merely simpler: recursively
  # scrubbing the *whole* pkgs tree (the more obvious approach, tried
  # first) reaches into pkgs.stdenv's own internal bootstrap-stage
  # cross-references on x86_64-darwin and breaks an internal consistency
  # assertion there (isBuiltByBootstrapFilesCompiler). home-manager's own
  # test suite hits the identical problem and solves it the same way
  # (tests/darwinScrublist.nix): start from real pkgs, scrub only a named
  # list of leaf application packages, never touch stdenv or anything not
  # explicitly named. Ported directly rather than rediscovered
  # independently -- their own comment on it: "TODO: figure out stdenv
  # stubbing so we don't have to do this".
  #
  # A useful side effect: packages referenced only through option-value
  # string interpolation rather than home.packages (nix-direnv, this
  # repo's own kubernetes-helmPlugins.helm-diff) are never in
  # installedPackageNames, so they are never scrubbed and their
  # interpolated paths stay real absolute paths automatically -- no
  # separate exception list needed for that class of failure at all.

  # Packages that must stay real regardless of installedPackageNames
  # membership, for two distinct reasons, both found by actually trying to
  # build the smoke test rather than assumed up front -- the failure mode
  # is identical either way: a real derivation ends up depending on the
  # fake "@name@" placeholder as one of its own build inputs, and the
  # builder can't run at all (not "package missing" -- literally "build
  # input @jq-1.7.1@ does not exist").
  #
  #  - fzf/zoxide/direnv: shell-tools.nix's mkInit genuinely *executes*
  #    these at build time (pkgs.runCommand "${cmd} > $out", capturing
  #    their static shell-init output), not merely referencing their path
  #    in rendered text.
  #  - Everything else here: also something this repo installs, but also
  #    something Home Manager's own internal derivations (fish config
  #    rendering, session-vars generation, gettext-based message
  #    formatting, mime-database updates in the profile's own activation)
  #    or nixpkgs' own darwin bootstrap (apple-sdk's build needs real jq)
  #    depend on as a genuine build input, independent of anything in this
  #    repo's own modules. Unlike programs.fish's generateCompletions or
  #    manual.manpages above, there is no "just disable it" option for
  #    either of these, so the fix is keeping the tool real rather than
  #    scrubbing something nixpkgs itself needs.
  #
  #    This is home-manager's own darwinScrublist.nix whitelist in full
  #    (its comment: "Needed by pretty much all tests"), taken wholesale
  #    rather than rediscovered one CI failure at a time -- upstream
  #    already did the exhaustive enumeration once; the first two attempts
  #    at trimming it down here (assuming only a subset applied) each cost
  #    a full CI round-trip to find the next omission.
  mustStayReal = [
    "fzf"
    "zoxide"
    "direnv"
    "coreutils"
    "crudini"
    "jq"
    "desktop-file-utils"
    "diffutils"
    "findutils"
    "glibcLocales"
    "gettext"
    "gnugrep"
    "gnused"
    "shared-mime-info"
    "emptyDirectory"
    "babelfish"
    "fish"
    "lndir"
    "bash"
  ];
  mkScrubbedPkgs =
    realPkgs:
    let
      overlay =
        _final: super:
        nixpkgs.lib.mapAttrs (
          name: value:
          if
            builtins.elem name installedPackageNames
            && !(builtins.elem name mustStayReal)
            && nixpkgs.lib.isDerivation value
          then
            scrubDerivation name value
          else
            value
        ) super;
    in
    (nixpkgs.lib.makeExtensible (_final: realPkgs)).extend (
      final: super: overlay final super // { buildPackages = super.buildPackages.extend overlay; }
    );

  # Same home-manager-input selection as mkDarwinConfig: x86_64-darwin rides
  # the pinned 25.05 home-manager-darwin input, everything else rides the
  # rolling home-manager input.
  hmInputFor = system: if isX86Darwin system then home-manager-darwin else home-manager;
  hmModulesFor = system: hmInputFor system + "/modules/modules.nix";
  # Home Manager's own modules use an `lib.hm.*` namespace (deprecations,
  # string-casing helpers, etc.) added by their own stdlib-extended.nix, not
  # present in plain nixpkgs.lib. Every one of HM's modules assumes it is
  # there; without it, evaluation dies on the first module that reaches for
  # `lib.hm.deprecations` or similar. Mirrors home-manager's own test suite
  # (tests/default.nix), which does the same thing for the same reason.
  hmLibFor = system: import (hmInputFor system + "/modules/lib/stdlib-extended.nix") nixpkgs.lib;

  # The module list nmt evaluates: home-manager's own modules (scrubbed
  # pkgs, check = false so HM's own option-type-mismatch warnings don't fire
  # against placeholder values) plus this repo's own profile, plus a
  # fixture supplying pkgs/user via _module.args -- nmt's own
  # evalModules call has no specialArgs passthrough, so anything a module
  # destructures as a function argument (pkgs included) has to arrive this
  # way instead. base.nix's own mkForce on home.homeDirectory (keyed off
  # testUser.username and the target system) supersedes any default nmt
  # would otherwise pick, so no separate override is needed here.
  #
  # tier/withGui/userData default to the harness's own baseline (full tier,
  # headless, unmodified testUser) so the existing symlink/tmux/shell/dotfile
  # tests need no changes; a variant test set (GUI, excludeFeatures,
  # extraModulePaths) overrides one or more of these to get a different
  # rendered tree out of the same harness plumbing. userData is layered onto
  # testUser (// userDataOverrides), not substituted outright, so a variant
  # only has to state what it's changing.
  mkNmtModules =
    {
      system,
      tier ? "full",
      withGui ? false,
      userDataOverrides ? { },
    }:
    let
      realPkgs = pkgsFor system;
      scrubbedPkgs = mkScrubbedPkgs realPkgs;
      effectiveUser = testUser // userDataOverrides;
    in
    import (hmModulesFor system) {
      lib = hmLibFor system;
      pkgs = scrubbedPkgs;
      check = false;
    }
    ++ mkProfile {
      inherit tier withGui system;
      userData = effectiveUser;
    }
    ++ [
      {
        _module.args = {
          # mkForce: misc/nixpkgs.nix (pulled in by modules.nix above) also
          # sets _module.args.pkgs, from its own reimport of pkgsPath at the
          # same default priority as a bare assignment here -- an outright
          # conflict, not merely a default to override. mkForce breaks the
          # tie in favor of the scrubbed pkgs, which is the one point of
          # this harness. pkgsPath itself is forced to abort, matching
          # home-manager's own test suite (tests/default.nix): nothing in
          # this repo's modules should ever need a real nixpkgs reimport,
          # and an abort here turns a silent real build into a loud failure
          # if that assumption ever breaks.
          pkgsPath = abort "pkgsPath is unavailable in the nmt harness: every package must come from the scrubbed pkgs";
          pkgs = nixpkgs.lib.mkForce scrubbedPkgs;
          user = effectiveUser;
        };
        # programs.fish.generateCompletions builds one real runCommand
        # derivation per package in home.packages (reading each package's
        # /share/man to synthesize completions), regardless of whether the
        # package itself is scrubbed -- unlike a string interpolation, this
        # is home-manager's own module code constructing new, genuinely
        # buildable derivations from the package list, which defeats the
        # entire premise of a scrub-based, build-free harness. Off here
        # only; the real profile still ships real completions.
        programs.fish.generateCompletions = false;
        # manual.manpages.enable (on by default) builds an options.json and
        # a full manpage from the whole option tree, using python3 as a
        # real build input -- python3 is also something this repo installs
        # (lang-python.nix), so mkScrubbedPkgs scrubs it, and the manual
        # build then fails on a fake build input. Matches home-manager's
        # own test suite (tests/default.nix), whose comment is the reason
        # to disable this rather than add another scrub exception: "Avoid
        # including documentation since this will cause unnecessary
        # rebuilds of the tests."
        manual.manpages.enable = false;
      }
    ];

  # nmt's own `pkgs` (unlike the scrubbed pkgs above) must be real: it backs
  # the handful of packages (coreutils, ncurses, diffutils, findutils,
  # gnugrep, gnused) that actually run the assertion scripts themselves, via
  # a real runCommandLocal build. Tests live in ./tests/nmt, one file per
  # area, folded together the same way home-manager's own tests/default.nix
  # folds its per-module test directories.
  #
  # Each distinct (tier, withGui, userDataOverrides) combination needs its
  # own nmt instance, since nmt evaluates one fixed module list per
  # instance: a test asserting on a GUI-only or excludeFeatures-only
  # rendered tree can't share the harness's default full/headless instance.
  # `tests` is an already-imported attrset (not a path): callers below
  # sometimes merge in a system-conditional subset (e.g. darwin's
  # keybindings.toml only applies on darwin systems), which is simplest to
  # decide with a plain Nix `lib.optionalAttrs` at the call site rather than
  # smuggling system-detection into the bash assertion scripts themselves.
  mkNmtTests =
    {
      system,
      tier ? "full",
      withGui ? false,
      userDataOverrides ? { },
      tests,
    }:
    import nmtSrc {
      lib = hmLibFor system;
      pkgs = pkgsFor system;
      modules = mkNmtModules {
        inherit
          system
          tier
          withGui
          userDataOverrides
          ;
      };
      testedAttrPath = [
        "home"
        "activationPackage"
      ];
      inherit tests;
    };
in
{
  # mkNmtModules stays internal: only mkNmtTests (below) calls it.
  inherit testUser mkNmtTests;
}
