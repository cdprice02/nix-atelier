{
  description = "nix system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # darwinConfigurations pin a nixpkgs release branch instead of tracking
    # nixpkgs-unstable, for two independent reasons:
    #   1. nixpkgs-unstable dropped x86_64-darwin support (release notes:
    #      nixos.org/manual/nixpkgs/unstable/release-notes#x86_64-darwin-26.11).
    #   2. This is an Intel 2018 MacBook Pro capped at macOS 13 (Ventura,
    #      Darwin 22). nixpkgs 25.11-darwin and later bumped darwinMinVersion
    #      to 14.0: their binaries link against macOS 14's libc++ (e.g.
    #      std::pmr symbols) and abort under dyld on macOS 13. 25.05-darwin is
    #      the newest release still targeting macOS <=13 (darwinMinVersion
    #      11.3) AND still supporting x86_64-darwin, so it is the ceiling for
    #      this machine.
    # Tradeoff: 25.05 is past its upstream security-support window. The
    # binding constraint is the OS (can't upgrade a 2018 Intel Mac past
    # Ventura), not security recency: revisit only if the machine is replaced
    # or moved to NixOS. Crucially, BOTH reasons above are specific to
    # x86_64-darwin: aarch64-darwin (Apple Silicon) is a first-class platform
    # on nixpkgs-unstable AND runs current macOS, so it has neither problem.
    # This pin therefore applies to x86_64-darwin ONLY; aarch64-darwin tracks
    # the rolling nixpkgs/home-manager/nix-darwin inputs, same as Linux (the
    # arch split lives in mkDarwinConfig below). Every Linux/WSL2 profile also
    # stays on rolling nixpkgs-unstable above.
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-25.05-darwin";
    # nix-darwin enforces that its release branch and its nixpkgs input's
    # release branch correspond (master pairs with nixpkgs-unstable;
    # nix-darwin-YY.MM pairs with nixpkgs-YY.MM-darwin). We carry two, one per
    # darwin pair: nix-darwin (master) for aarch64-darwin, nix-darwin-x86
    # (25.05) for x86_64-darwin.
    nix-darwin.url = "github:nix-darwin/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-darwin-x86.url = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
    nix-darwin-x86.inputs.nixpkgs.follows = "nixpkgs-darwin";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # x86_64-darwin builds against pinned nixpkgs-25.05-darwin, so it needs the
    # matching home-manager release branch. Home Manager's module code is
    # coupled to its nixpkgs release: the master branch's
    # `home-manager-applications` passes a bare "/Applications" string to
    # buildEnv, which the pinned nixpkgs release's stricter builder rejects
    # (it expects a list). Mirrors the nix-darwin release-correspondence
    # pairing above. Also lines up with home.stateVersion = "25.05".
    # (aarch64-darwin uses the rolling `home-manager` input above.)
    home-manager-darwin = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # follows nixpkgs-darwin (not nixpkgs) so caret's trivial file-copy
    # derivation still builds on x86_64-darwin, which rolling nixpkgs-unstable
    # has dropped; this pins caret's nixpkgs for every system, but caret has
    # no real version dependency so that's harmless.
    caret = {
      url = "github:cdprice02/caret";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
    # Only ever imported when a machine's user.nix sets sopsFile; see
    # mkProfile's sopsMods below. Follows nixpkgs (not nixpkgs-darwin):
    # unlike caret, sops-nix has no x86_64-darwin-specific build concern, so
    # it doesn't need the same override.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-darwin,
    nix-darwin,
    nix-darwin-x86,
    home-manager,
    home-manager-darwin,
    rust-overlay,
    caret,
    sops-nix,
    ...
  }: let
    # ── Identity ────────────────────────────────────────────────────────────
    # Identity is loaded from user.nix (gitignored, never committed).
    # Copy user.nix.example to user.nix and fill in your values.
    # builtins.getEnv is impure (value varies per eval), so all home-manager
    # switch calls require --impure. Alternatives (a hardcoded absolute path,
    # sops-nix) trade portability or simplicity for that impurity.
    #
    # Default location is $HOME/.nix-atelier/user.nix. If you've cloned this
    # repo somewhere else, set NIX_CONFIG_USER_FILE to the full path of your
    # user.nix instead of relying on the default.
    homeDir = builtins.getEnv "HOME";
    # SUDO_USER is set by sudo to the invoking (real) user. `sudo
    # darwin-rebuild switch` / `sudo nixos-rebuild switch` reset $HOME to
    # root's home (/var/root), so getEnv "HOME" alone would miss the real
    # user.nix and silently fall back to user.nix.example (username
    # "yourusername"): which then fails activation on `system.primaryUser`.
    # Fall back to the invoking user's home in that case, trying both the
    # darwin (/Users) and Linux (/home) prefixes rather than probing the
    # eval system. First existing candidate wins.
    sudoUser = builtins.getEnv "SUDO_USER";
    userNixPathOverride = builtins.getEnv "NIX_CONFIG_USER_FILE";
    userNixCandidates =
      nixpkgs.lib.optional (userNixPathOverride != "") userNixPathOverride
      ++ nixpkgs.lib.optional (homeDir != "") (homeDir + "/.nix-atelier/user.nix")
      ++ nixpkgs.lib.optionals (sudoUser != "") [
        "/Users/${sudoUser}/.nix-atelier/user.nix"
        "/home/${sudoUser}/.nix-atelier/user.nix"
      ];
    existingUserNix = builtins.filter builtins.pathExists userNixCandidates;
    userBase =
      if userNixPathOverride != ""
      then
        # Explicitly set: a typo'd path is a real mistake, not a fresh
        # checkout that hasn't created user.nix yet: fail loudly instead of
        # silently building with the placeholder identity.
        (
          if builtins.pathExists userNixPathOverride
          then import userNixPathOverride
          else throw "NIX_CONFIG_USER_FILE=${userNixPathOverride} does not exist"
        )
      else if existingUserNix != []
      then import (builtins.head existingUserNix)
      else import (self + /user.nix.example);
    # Derive SSH key name from email prefix: key file: ~/.ssh/<sshKey>. Shared
    # with testUser below (the nmt harness's identity-independent stand-in),
    # so both go through the same derivation.
    mkUser = base: base // {sshKey = builtins.elemAt (builtins.split "@" base.email) 0;};
    user = mkUser userBase;

    pkgsConfig = {allowUnfree = true;};

    # ── Release pairing guard ────────────────────────────────────────────────
    # Home Manager's module code is coupled to its nixpkgs release: a mismatched
    # pair evaluates but emits deprecation warnings and can silently generate
    # wrong config (HM itself only warns, via home.enableNixpkgsReleaseCheck).
    # This repo maintains two independent pairs: rolling (Linux/WSL2) and
    # pinned (darwin): so a `nix flake update <one-input>` can desync either
    # one.
    #
    # Fail evaluation instead of warning, so drift can't be ignored. To fix a
    # failure here, update BOTH inputs of the offending pair together (`just
    # update`, which never updates a single input).
    hmRelease = hm: (builtins.fromJSON (builtins.readFile (hm + "/release.json"))).release;
    checkReleasePair = label: hm: npkgs: let
      hmVer = hmRelease hm;
      npkgsVer = npkgs.lib.trivial.release;
    in
      nixpkgs.lib.throwIf (hmVer != npkgsVer) ''
        ${label}: home-manager (${hmVer}) and nixpkgs (${npkgsVer}) releases disagree.

        Home Manager modules are coupled to their nixpkgs release; a mismatched
        pair produces deprecation warnings and can generate incorrect config.

        Fix: update both inputs of this pair together: `just update`.
      ''
      true;

    # Evaluated by every config output below (see mkHomeConfig / mkDarwinConfig).
    # The rolling pair (nixpkgs + home-manager master) backs Linux/WSL2 AND
    # aarch64-darwin; the pinned pair backs x86_64-darwin only.
    linuxPairOk = checkReleasePair "rolling (Linux/WSL2 + aarch64-darwin)" home-manager nixpkgs;
    darwinPairOk = checkReleasePair "x86_64-darwin (pinned)" home-manager-darwin nixpkgs-darwin;

    # ── Helpers ──────────────────────────────────────────────────────────────
    # Every system this flake produces per-system outputs for (devShells,
    # formatter, packages). Named once rather than repeating the literal at
    # each genAttrs call site, so adding or dropping a platform is one edit.
    # `checks` deliberately does NOT use this: see its own comment for why it
    # is Linux-only.
    allSystems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    linuxSystems = ["x86_64-linux" "aarch64-linux"];

    isLinux = s: builtins.elem s linuxSystems;
    # Only x86_64-darwin uses the pinned 25.05 darwin inputs (see input
    # comment). aarch64-darwin rides the rolling inputs, same as Linux.
    isX86Darwin = s: s == "x86_64-darwin";

    # nixpkgs with rust-overlay applied
    mkPkgs = system:
      import nixpkgs {
        inherit system;
        config = pkgsConfig;
        overlays = [rust-overlay.overlays.default];
      };

    # x86_64-darwin uses the pinned nixpkgs-darwin input (see the flake input
    # comment above for why), not the rolling nixpkgs-unstable used everywhere
    # else: including aarch64-darwin.
    mkPkgsDarwin = system:
      import nixpkgs-darwin {
        inherit system;
        config = pkgsConfig;
        overlays = [rust-overlay.overlays.default];
      };

    # Right package set for any system: pinned nixpkgs-darwin for x86_64-darwin,
    # rolling nixpkgs for everything else (Linux + aarch64-darwin).
    pkgsFor = system:
      if isX86Darwin system
      then mkPkgsDarwin system
      else mkPkgs system;

    # user is threaded into every module via specialArgs.
    mkSpecialArgs = system: {inherit system self user;};

    # ── Feature/tier data model ────────────────────────────────────────────────
    # features.nix: name -> module path registry. core/env aren't in it: they're
    # an always-on prefix mkProfile adds unconditionally, not a selectable
    # feature. Both tiers are derived from that same registry, so a new feature
    # joins `full` automatically and there is no second list to keep in sync.
    features = import ./modules/features.nix;
    tiers = {
      minimal = [];
      full = builtins.attrNames features;
    };
    toolCatalog = import ./modules/tool-catalog.nix;

    # A features.nix entry is either a bare path or an attrset
    # { module; unsupported; } (see that file's own comment). These two
    # accessors are the only place that shape distinction is unwrapped.
    featureModule = f:
      if builtins.isAttrs f
      then f.module
      else f;
    featureUnsupported = f:
      if builtins.isAttrs f
      then (f.unsupported or [])
      else [];

    # ── Docs generation ────────────────────────────────────────────────────
    # Realized package identities (p.pname or p.name) across every already-
    # built home/darwin config: reuses the actual mkProfile composition
    # rather than statically re-scanning modules/features/*.nix, so it also
    # catches packages home-manager's own program modules inject implicitly
    # (e.g. programs.git.delta.enable -> the delta package, with no
    # home.packages entry anywhere in this repo).
    installedPackageNames = let
      pkgIdent = p: p.pname or p.name;
      homePkgLists = map (cfg: cfg.config.home.packages) (builtins.attrValues self.homeConfigurations);
      darwinPkgLists = map (cfg: cfg.config.home-manager.users.${user.username}.home.packages) (builtins.attrValues self.darwinConfigurations);
    in
      nixpkgs.lib.unique (map pkgIdent (nixpkgs.lib.flatten (homePkgLists ++ darwinPkgLists)));

    # Bidirectional: every installed package needs a tool-catalog.nix entry
    # (or an explicit exclusion), and every catalog entry needs to actually
    # correspond to something installed: fail eval rather than let the two
    # drift silently.
    catalogedNames = nixpkgs.lib.concatMap (e: e.matches) toolCatalog.entries;
    uncatalogedInstalled = nixpkgs.lib.subtractLists (catalogedNames ++ toolCatalog.infraExclude) installedPackageNames;
    staleCatalogEntries = nixpkgs.lib.subtractLists installedPackageNames catalogedNames;
    docsCatalogValid =
      nixpkgs.lib.throwIf (uncatalogedInstalled != [])
      "modules/tool-catalog.nix is missing entries for installed packages: ${toString uncatalogedInstalled}"
      (
        nixpkgs.lib.throwIf (staleCatalogEntries != [])
        "modules/tool-catalog.nix has entries for packages that aren't installed anywhere: ${toString staleCatalogEntries}"
        true
      );

    docsGenerated =
      (import ./modules/docs-gen.nix {inherit (nixpkgs) lib;})
      {
        inherit tiers toolCatalog;
        homeConfigNames = builtins.attrNames self.homeConfigurations;
        darwinConfigNames = builtins.attrNames self.darwinConfigurations;
      };

    # ── Profile compositor ────────────────────────────────────────────────────
    # Produces the ordered module list for a profile.
    # tier    : "minimal" | "full"
    # withGui : bool: gui module auto-selected from system
    # userData / featuresOverride default to the real top-level `user` /
    # `features` bindings, so every real call site (home/darwin configs) below
    # is unaffected. The nmt harness overrides both: userData so its fixture is
    # genuinely identity-independent (previously it silently read whichever
    # real user.nix happened to be on the evaluating machine -- harmless today
    # only because this machine's extraFeatures/excludeFeatures/
    # extraModulePaths happen to be empty, but a contributor with a private
    # extraModulePaths entry would have had it evaluated into `nix flake
    # check`), and featuresOverride so the platform-filtering check
    # (feature-platform-filtering below) can exercise a synthetic unsupported
    # feature without adding test-only noise to the real, shipped registry.
    mkProfile = {
      tier,
      withGui,
      system,
      userData ? user,
      featuresOverride ? features,
    }: let
      resolveFeature = name:
        featuresOverride.${
          name
        }
        or (throw ''
          unknown feature "${name}": valid features: ${builtins.concatStringsSep ", " (builtins.attrNames featuresOverride)}
        '');
      # Tier defaults plus user.nix's extraFeatures, deduplicated (a name in
      # both is not an error: the module system already dedupes imports by
      # file, so this has always been silently fine -- unique here just
      # avoids resolving the same name twice). excludeFeatures is the
      # inverse escape hatch: names to drop regardless of where they came
      # from, and also how a machine silences the unsupported-platform
      # warning below for a feature it was never going to use anyway.
      requestedNames =
        nixpkgs.lib.unique
        ((tiers.${tier} or (throw "unknown tier \"${tier}\"")) ++ (userData.extraFeatures or []));
      keptNames = nixpkgs.lib.subtractLists (userData.excludeFeatures or []) requestedNames;

      supportedOn = name: !(builtins.elem system (featureUnsupported (resolveFeature name)));
      usableNames = builtins.filter supportedOn keptNames;
      skippedNames = builtins.filter (n: !(supportedOn n)) keptNames;

      featureMods = map (n: featureModule (resolveFeature n)) usableNames;

      # Absolute paths to private, machine-specific modules outside this
      # repo: a string absolute path imports to a real module, and relative
      # imports inside it resolve against the real filesystem, the same
      # --impure trick user.nix itself relies on. See examples/private-config/
      # for a worked example. Empty by default.
      privateMods = map import (userData.extraModulePaths or []);

      guiMods =
        if !withGui
        then []
        else if isLinux system
        then [./modules/gui-linux.nix]
        else [./modules/gui-darwin.nix];

      # Opt-in only, gated on user.nix's sopsFile being set -- no separate
      # boolean, since a set sopsFile already says everything a flag would.
      # This repo is public and forked by others (see CONTRIBUTING.md):
      # sops-nix decrypts at *activation* time using whichever age key is on
      # disk, so if this were wired in unconditionally, `home-manager
      # switch` would hard-fail on any machine that isn't this repo owner's
      # (no matching age key). Importing the module itself is otherwise
      # inert (declares options, no activation-time effect) with no secrets
      # configured, but keeping the import itself gated too means it's
      # genuinely absent from the module tree, not just unconfigured, for
      # anyone who hasn't opted in.
      sopsMods =
        if (userData.sopsFile or null) != null
        then [sops-nix.homeManagerModules.sops ./modules/secrets-sops.nix]
        else [];
    in
      nixpkgs.lib.warnIf (skippedNames != []) ''
        Skipping features unsupported on ${system}: ${nixpkgs.lib.concatStringsSep ", " skippedNames}.
        Add them to excludeFeatures in user.nix to silence this.
      ''
      ([./modules/base.nix ./modules/env.nix caret.homeManagerModules.default]
        ++ featureMods
        ++ privateMods
        ++ guiMods
        ++ sopsMods);

    # ── Test harness (nmt) ───────────────────────────────────────────────────
    # nmt (home-manager's own module test framework) evaluates a home-manager
    # configuration with every derivation's outPath replaced by a
    # "@package-name@" placeholder, then runs bash assertions against the
    # rendered home-files tree. It never builds a real package, so it runs on
    # every system this flake targets, including x86_64-darwin, where `checks`
    # otherwise has almost nothing to say (see docs-drift's own comment below).
    nmtSrc = builtins.fetchTarball {
      url = "https://git.sr.ht/~rycee/nmt/archive/v0.5.1.tar.gz";
      sha256 = "0qhn7nnwdwzh910ss78ga2d00v42b0lspfd7ybl61mpfgz3lmdcj";
    };

    # user.nix.example, not a real user.nix: tests must be identity-independent,
    # not a description of whichever machine happens to be evaluating them.
    testUser = mkUser (import (self + /user.nix.example));

    # Replaces a single derivation's outPath with "@name@" (its own name, not
    # the caller's attribute name, so e.g. buildPackages.gettext and
    # top-level gettext scrub identically). Reached only for the specific
    # top-level packages named below, never applied to the rest of pkgs.
    scrubDerivation = name: value:
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
    mkScrubbedPkgs = realPkgs: let
      overlay = _final: super:
        nixpkgs.lib.mapAttrs (
          name: value:
            if
              builtins.elem name installedPackageNames
              && !(builtins.elem name mustStayReal)
              && nixpkgs.lib.isDerivation value
            then scrubDerivation name value
            else value
        )
        super;
    in
      (nixpkgs.lib.makeExtensible (_final: realPkgs)).extend (
        final: super: overlay final super // {buildPackages = super.buildPackages.extend overlay;}
      );

    # Same home-manager-input selection as mkDarwinConfig: x86_64-darwin rides
    # the pinned 25.05 home-manager-darwin input, everything else rides the
    # rolling home-manager input.
    hmInputFor = system:
      if isX86Darwin system
      then home-manager-darwin
      else home-manager;
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
    mkNmtModules = {
      system,
      tier ? "full",
      withGui ? false,
      userDataOverrides ? {},
    }: let
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
    mkNmtTests = {
      system,
      tier ? "full",
      withGui ? false,
      userDataOverrides ? {},
      tests,
    }:
      import nmtSrc {
        lib = hmLibFor system;
        pkgs = pkgsFor system;
        modules = mkNmtModules {inherit system tier withGui userDataOverrides;};
        testedAttrPath = ["home" "activationPackage"];
        inherit tests;
      };

    # ── Home Manager (standalone Linux/WSL2) ────────────────────────────────
    mkHomeConfig = {
      tier,
      withGui,
      system,
    }:
    # assert forces the release-pair check before any config is built. No
    # feature/tier-name validation is needed here: tiers are derived directly
    # from features.nix's own attrNames (see the tiers binding above), so
    # there is no second, hand-maintained list that could disagree with it.
      assert linuxPairOk;
        home-manager.lib.homeManagerConfiguration {
          pkgs = mkPkgs system;
          extraSpecialArgs = mkSpecialArgs system;
          modules =
            (mkProfile {inherit tier withGui system;})
            ++ [{nixpkgs.config = pkgsConfig;}];
        };

    # Cartesian product of tier x gui x arch: every homeConfigurations name
    # falls out of this loop, so a new feature (which only changes what
    # `full` contains) never requires touching this list, and neither does a
    # new tier.
    linuxArches = ["x86_64-linux" "aarch64-linux"];
    mkHomeConfigName = tierName: withGui: arch:
      tierName
      + (nixpkgs.lib.optionalString withGui "-gui")
      + (nixpkgs.lib.optionalString (arch == "aarch64-linux") "-aarch64");
    homeConfigMatrix = nixpkgs.lib.concatMap (
      tierName:
        nixpkgs.lib.concatMap (
          withGui:
            map (arch: {
              name = mkHomeConfigName tierName withGui arch;
              value = mkHomeConfig {
                tier = tierName;
                inherit withGui;
                system = arch;
              };
            })
            linuxArches
        ) [false true]
    ) (builtins.attrNames tiers);

    # ── Darwin (nix-darwin + home-manager) ──────────────────────────────────
    # Darwin always includes GUI: nix-darwin implies a graphical macOS
    # environment, and it's always the `full` tier -- a headless or minimal
    # Mac isn't a real use case this repo targets.
    mkDarwinConfig = {system}: let
      # x86_64-darwin rides the pinned 25.05 trio (nixpkgs-darwin +
      # nix-darwin-x86 + home-manager-darwin); aarch64-darwin rides the rolling
      # trio (nixpkgs + nix-darwin + home-manager), same inputs as Linux. Each
      # nix-darwin/home-manager must match its nixpkgs release, so all three
      # move together per arch.
      x86 = isX86Darwin system;
      darwinLib =
        if x86
        then nix-darwin-x86
        else nix-darwin;
      hmModule =
        if x86
        then home-manager-darwin.darwinModules.home-manager
        else home-manager.darwinModules.home-manager;
      # assert forces the matching release-pair check before any config builds.
      pairOk =
        if x86
        then darwinPairOk
        else linuxPairOk;
    in
      assert pairOk;
        darwinLib.lib.darwinSystem {
          inherit system;
          specialArgs = mkSpecialArgs system;
          modules = [
            ./system/darwin.nix
            hmModule
            {
              nixpkgs.pkgs = pkgsFor system;
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = false;
                backupFileExtension = "bk";
                extraSpecialArgs = mkSpecialArgs system;
                users.${user.username} = {
                  imports = mkProfile {
                    inherit system;
                    tier = "full";
                    withGui = true;
                  };
                };
              };
            }
          ];
        };
  in {
    # ── homeConfigurations ──────────────────────────────────────────────────
    # Bootstrap: nix run home-manager -- switch --flake ~/.nix-atelier#<name>
    # After first apply: home-manager switch --flake ~/.nix-atelier#<name>
    #
    # Generated from tiers x {gui,no-gui} x {x86_64,aarch64}: adding a tier or
    # a feature never means adding a name here.
    homeConfigurations = builtins.listToAttrs homeConfigMatrix;

    # ── darwinConfigurations ────────────────────────────────────────────────
    # Bootstrap: sudo darwin-rebuild switch --flake ~/.nix-atelier#<name>
    darwinConfigurations = {
      "full-darwin" = mkDarwinConfig {
        system = "x86_64-darwin";
      };
      "full-darwin-aarch64" = mkDarwinConfig {
        system = "aarch64-darwin";
      };
    };

    # ── nixosConfigurations ─────────────────────────────────────────────────
    # NixOS support is tracked in issue #5. Requires hardware-configuration.nix
    # and a mkNixosConfig helper (analogous to mkDarwinConfig above).

    # ── devShells ────────────────────────────────────────────────────────────
    # `nix develop`: lint tools for contributors, matching
    # .pre-commit-config.yaml and CI's lint-* jobs.
    devShells =
      nixpkgs.lib.genAttrs allSystems
      (system: let
        pkgs = pkgsFor system;
      in {
        default = pkgs.mkShell {
          packages = with pkgs; [
            alejandra
            statix
            deadnix
            markdownlint-cli
            pre-commit
          ];
        };
      });

    # ── formatter ────────────────────────────────────────────────────────────
    # `nix fmt`: alejandra, matching .pre-commit-config.yaml and CI's
    # lint-alejandra job so all three (editor, pre-commit, CI) agree.
    formatter =
      nixpkgs.lib.genAttrs allSystems
      (system: (pkgsFor system).alejandra);

    # ── packages ─────────────────────────────────────────────────────────────
    # Buildable outputs of docsGenerated, for `just docs` to copy over the
    # committed docs/*.md. docsGenerated's content is pure Nix data (no
    # platform-dependent logic), but `pkgs.writeText` still needs a matching-
    # platform builder to realize it: unlike the eval-only `checks` output,
    # this needs the full system list (same as devShells/formatter) so
    # `just docs` builds natively wherever it's run, darwin included.
    packages =
      nixpkgs.lib.genAttrs allSystems
      (
        system: let
          pkgs = pkgsFor system;
        in {
          docs-profiles-md = pkgs.writeText "profiles.md" docsGenerated.profilesMd;
          docs-tools-md = pkgs.writeText "tools.md" docsGenerated.toolsMd;
        }
      );

    # ── checks ───────────────────────────────────────────────────────────────
    # The Nix-specific verification: nmt's assertion-level checks (rendered
    # content, GUI/headless, excludeFeatures/extraModulePaths composability,
    # per-platform feature filtering), plus generated-docs drift. Uniform
    # across every system in `allSystems` -- no per-platform gap, because
    # nothing in here builds a real profile closure. That used to not be true:
    # this output previously also carried `activation-*` (a real build of
    # every Linux homeConfiguration, since darwin's closures live in
    # `darwinConfigurations` and were never included here), which meant it
    # could only meaningfully run on a Linux CI runner -- `nix flake check` on
    # this machine skipped straight to `docs-drift` and nothing else. Removed
    # once CI's own `build-linux` job started covering the same 4 x86_64-linux
    # profiles under a better name (`build-linux (full)` vs. `activation-full`):
    # keeping both was pure duplication, not extra coverage. `build-linux`/
    # `build-darwin` remain the only things that build a real closure; this
    # output is what makes that unnecessary for everyday `just check` and CI's
    # per-PR gate, on every system, not just Linux.
    #
    # Deliberately does NOT contain the lints. It used to, which meant every PR
    # ran alejandra/statix/deadnix/markdownlint twice: once inside this output
    # via `flake-check`, and again as check.yml's four standalone `lint-*` jobs.
    # The standalone jobs are the ones worth keeping: a named red check tells
    # you which linter failed without opening a log, whereas a `flake-check`
    # failure does not. `just check` now runs `nix flake check` *and*
    # `just lint-all`, so a green local `just check` still covers lints: it
    # just gets them from the recipe rather than from this output, and lints the
    # working tree (what you are about to commit) instead of the last commit.
    checks = nixpkgs.lib.genAttrs allSystems (
      system: let
        # pkgsFor, not mkPkgs: mkPkgs always imports the rolling nixpkgs, which
        # has dropped x86_64-darwin, so any darwin check evaluated through it
        # dies with "Nixpkgs 26.11 has dropped support for x86_64-darwin"
        # before it can run. pkgsFor routes that one system to the pinned
        # nixpkgs-darwin input. Latent while `checks` was Linux-only.
        pkgs = pkgsFor system;
        # nmt's own `build` attrset already includes an `all` aggregate
        # (build.all), which surfaces here as nmt-all: a single check that
        # depends on every individual nmt test.
        nmtBuild =
          (mkNmtTests {
            inherit system;
            tests = import ./tests/nmt {inherit system;};
          }).build;

        # GUI variant: same harness, withGui = true instead of the default's
        # false. See tests/nmt/gui.nix and its negative counterpart
        # tests/nmt/gui-absent.nix (which runs in the default instance above,
        # no override needed there).
        guiNmtBuild =
          (mkNmtTests {
            inherit system;
            withGui = true;
            tests = import ./tests/nmt/gui.nix {
              inherit system;
              inherit (nixpkgs) lib;
            };
          }).build;

        # Composition variant: excludeFeatures and extraModulePaths together,
        # proving both actually take effect rather than merely evaluating.
        # toString on the fixture path resolves it the same way a real
        # extraModulePaths string entry would (see mkProfile's own comment on
        # userData/featuresOverride) -- no impurity, since the fixture lives
        # inside this flake's own source tree.
        compositionNmtBuild =
          (mkNmtTests {
            inherit system;
            userDataOverrides = {
              excludeFeatures = ["tmux"];
              extraModulePaths = [(toString ./tests/nmt/fixtures/private-identity.nix)];
            };
            tests = import ./tests/nmt/composition.nix;
          }).build;

        # Pure eval-level check (not nmt: this is about which modules
        # mkProfile *selects*, not what a rendered tree contains) that an
        # `unsupported`-declared feature is actually dropped on its excluded
        # system and kept everywhere else. Uses featuresOverride rather than
        # a real features.nix entry: modules/features.nix has no feature
        # with a genuine `unsupported` list right now (qmk turned out to
        # build everywhere -- see that file's own comment), and adding a
        # throwaway one there would pollute the real `full` tier for every
        # user just to exercise this one code path.
        platformFilteringFixtureFeatures =
          features
          // {
            fixture-unsupported = {
              module = ./tests/nmt/fixtures/inert-feature.nix;
              unsupported = [system];
            };
          };
        platformFilteringOtherSystem =
          if system == "aarch64-linux"
          then "x86_64-linux"
          else "aarch64-linux";
        platformFilteringModsFor = testSystem:
          mkProfile {
            tier = "minimal";
            withGui = false;
            system = testSystem;
            userData = testUser // {extraFeatures = ["fixture-unsupported"];};
            featuresOverride = platformFilteringFixtureFeatures;
          };
        platformFilteringDroppedOnSelf =
          !(builtins.elem ./tests/nmt/fixtures/inert-feature.nix (platformFilteringModsFor system));
        platformFilteringKeptOnOther =
          builtins.elem ./tests/nmt/fixtures/inert-feature.nix (platformFilteringModsFor platformFilteringOtherSystem);
      in
        (nixpkgs.lib.mapAttrs'
          (name: drv: {
            name = "nmt-${name}";
            value = drv;
          })
          nmtBuild)
        // (nixpkgs.lib.mapAttrs'
          (name: drv: {
            name = "nmt-gui-${name}";
            value = drv;
          })
          guiNmtBuild)
        // (nixpkgs.lib.mapAttrs'
          (name: drv: {
            name = "nmt-composition-${name}";
            value = drv;
          })
          compositionNmtBuild)
        // {
          # assert docsCatalogValid forces the bidirectional catalog check
          # (see above) before this even attempts the diff, so a catalog
          # drift and a docs-content drift fail with distinct messages.
          docs-drift = assert docsCatalogValid;
            pkgs.runCommand "check-docs-drift" {} ''
              if ! diff -u ${./docs/profiles.md} ${pkgs.writeText "profiles.md" docsGenerated.profilesMd}; then
                echo "docs/profiles.md is out of date: run 'just docs' and commit the result"
                exit 1
              fi
              if ! diff -u ${./docs/tools.md} ${pkgs.writeText "tools.md" docsGenerated.toolsMd}; then
                echo "docs/tools.md is out of date: run 'just docs' and commit the result"
                exit 1
              fi
              touch $out
            '';

          feature-platform-filtering =
            if platformFilteringDroppedOnSelf && platformFilteringKeptOnOther
            then pkgs.runCommand "check-feature-platform-filtering" {} "touch $out"
            else
              throw ''
                feature-platform-filtering: a feature declared unsupported on
                ${system} should be dropped from that system's module list and
                kept on every other system (droppedOnSelf=${builtins.toJSON platformFilteringDroppedOnSelf}
                keptOnOther=${builtins.toJSON platformFilteringKeptOnOther}).
              '';
        }
    );
  };
}
