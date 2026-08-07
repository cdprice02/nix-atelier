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
    # Only ever imported when a machine's user.nix opts in (useSops = true);
    # see mkProfile's sopsMods below. Follows nixpkgs (not nixpkgs-darwin):
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
    # Default location is $HOME/.nix-config/user.nix. If you've cloned this
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
      ++ nixpkgs.lib.optional (homeDir != "") (homeDir + "/.nix-config/user.nix")
      ++ nixpkgs.lib.optionals (sudoUser != "") [
        "/Users/${sudoUser}/.nix-config/user.nix"
        "/home/${sudoUser}/.nix-config/user.nix"
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

    # context and user are threaded into all modules via specialArgs so modules
    # can gate features (work.nix inclusion, copilot symlink, CLAUDE_PROFILE) on them.
    mkSpecialArgs = system: context: {inherit system self user context;};

    # ── Feature/tier data model ────────────────────────────────────────────────
    # features.nix: name -> module path registry. profiles.nix: tier -> list of
    # feature names. core/env aren't in the registry: they're an always-on
    # prefix mkProfile adds unconditionally, not a selectable feature.
    # profileList.nix: Linux profile name -> {context,tier,withGui,useFor};
    # single-sourced by homeConfigurations below and the generated docs.
    features = import ./modules/features.nix;
    profiles = import ./modules/profiles.nix;
    profileList = import ./modules/profile-list.nix;
    toolCatalog = import ./modules/tool-catalog.nix;
    resolveFeature = name:
      features.${
        name
      }
      or (throw ''
        unknown feature "${name}": valid features: ${builtins.concatStringsSep ", " (builtins.attrNames features)}
      '');

    # Forces every tier's feature list through resolveFeature so a typo in
    # profiles.nix fails any nix eval/build/flake check, not just a build of
    # the one tier that happens to reference it (tier resolution only happens
    # inside mkProfile, which nothing forces just by evaluating output *names*).
    profilesValidated =
      builtins.deepSeq
      (nixpkgs.lib.mapAttrs (_: map resolveFeature) profiles)
      true;

    # Same idiom for profileList: every entry's tier must be a real
    # profiles.nix key, checked eagerly so a typo fails immediately instead
    # of surfacing as a missing homeConfigurations attribute at build time.
    profileListValidated =
      builtins.deepSeq
      (nixpkgs.lib.mapAttrs (
          name: axes:
            if profiles ? ${axes.tier}
            then axes
            else throw "profile-list.nix: \"${name}\" has unknown tier \"${axes.tier}\""
        )
        profileList)
      true;

    # ── Docs generation (Task 15) ───────────────────────────────────────────
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
    # correspond to something installed: same "fail eval, don't drift
    # silently" idiom as profilesValidated/profileListValidated above.
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
        inherit profiles profileList toolCatalog;
        darwinConfigNames = builtins.attrNames self.darwinConfigurations;
      };

    # ── Profile compositor ────────────────────────────────────────────────────
    # Produces the ordered module list for a profile.
    # context : "personal" | "work"
    # tier    : "minimal" | "dev" | "server"
    # withGui : bool: gui module auto-selected from system
    mkProfile = {
      context,
      tier,
      withGui,
      system,
    }: let
      tierMods = map resolveFeature (profiles.${tier} or (throw "unknown tier \"${tier}\""));

      # Escape hatch: user.nix may declare extraFeatures = [ "k8s" ... ] to
      # layer extra named features onto whichever profile this machine
      # builds, beyond its tier's defaults. Unused by every profile defined
      # below; user is already in scope here the same way work.nix's
      # user.work.name/email are, so no signature threading needed.
      extraMods = map resolveFeature (user.extraFeatures or []);

      contextMods =
        if context == "work"
        then [./modules/work.nix]
        else [];

      guiMods =
        if !withGui
        then []
        else if isLinux system
        then [./modules/gui-linux.nix]
        else [./modules/gui-darwin.nix];

      # Opt-in only (user.nix: useSops = true;), never on by default. This
      # repo is public and forked by others (see CONTRIBUTING.md): sops-nix
      # decrypts at *activation* time using whichever age key is on disk, so
      # if this were wired in unconditionally, `home-manager switch` would
      # hard-fail on any machine that isn't this repo owner's (no matching
      # age key). Importing the module itself is otherwise inert (declares
      # options, no activation-time effect) with no secrets configured, but
      # keeping the import itself gated too means it's genuinely absent from
      # the module tree, not just unconfigured, for anyone who hasn't opted in.
      sopsMods =
        if (user.useSops or false)
        then [sops-nix.homeManagerModules.sops ./modules/secrets-sops.nix]
        else [];
    in
      [./modules/base.nix ./modules/env.nix caret.homeManagerModules.default]
      ++ tierMods
      ++ extraMods
      ++ contextMods
      ++ guiMods
      ++ sopsMods;

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

    # shell-tools.nix's mkInit genuinely *executes* fzf/zoxide/direnv at build
    # time (pkgs.runCommand "${cmd} > $out", capturing their static shell-init
    # output), rather than merely referencing their path in rendered text.
    # These three must stay real regardless of installedPackageNames
    # membership, or that runCommand's builder itself becomes unrunnable
    # (fake path, exit 127) -- the same failure class as the buildPackages
    # cases above, but caused by this repo's own modules rather than Home
    # Manager's.
    executedAtBuildTime = ["fzf" "zoxide" "direnv"];
    mkScrubbedPkgs = realPkgs: let
      overlay = _final: super:
        nixpkgs.lib.mapAttrs (
          name: value:
            if
              builtins.elem name installedPackageNames
              && !(builtins.elem name executedAtBuildTime)
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
    # fixture supplying pkgs/user/context via _module.args -- nmt's own
    # evalModules call has no specialArgs passthrough, so anything a module
    # destructures as a function argument (pkgs included) has to arrive this
    # way instead. base.nix's own mkForce on home.homeDirectory (keyed off
    # testUser.username and the target system) supersedes any default nmt
    # would otherwise pick, so no separate override is needed here.
    mkNmtModules = system: let
      realPkgs = pkgsFor system;
      scrubbedPkgs = mkScrubbedPkgs realPkgs;
    in
      import (hmModulesFor system) {
        lib = hmLibFor system;
        pkgs = scrubbedPkgs;
        check = false;
      }
      ++ mkProfile {
        context = "personal";
        tier = "dev";
        withGui = false;
        inherit system;
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
            user = testUser;
            context = "personal";
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
        }
      ];

    # nmt's own `pkgs` (unlike the scrubbed pkgs above) must be real: it backs
    # the handful of packages (coreutils, ncurses, diffutils, findutils,
    # gnugrep, gnused) that actually run the assertion scripts themselves, via
    # a real runCommandLocal build. Tests live in ./tests/nmt, one file per
    # area, folded together the same way home-manager's own tests/default.nix
    # folds its per-module test directories.
    mkNmtTests = system:
      import nmtSrc {
        lib = hmLibFor system;
        pkgs = pkgsFor system;
        modules = mkNmtModules system;
        testedAttrPath = ["home" "activationPackage"];
        tests = import ./tests/nmt {};
      };

    # ── Home Manager (standalone Linux/WSL2) ────────────────────────────────
    mkHomeConfig = {
      context,
      tier,
      withGui,
      system,
      ...
    }:
    # asserts force the release-pair and feature/tier-name checks before any
    # config is built.
      assert linuxPairOk;
      assert profilesValidated;
      assert profileListValidated;
        home-manager.lib.homeManagerConfiguration {
          pkgs = mkPkgs system;
          extraSpecialArgs = mkSpecialArgs system context;
          modules =
            (mkProfile {inherit context tier withGui system;})
            ++ [{nixpkgs.config = pkgsConfig;}];
        };

    # Both x86_64 and aarch64 variants for a Linux profile
    mkLinuxPair = args: {
      "${args.name}" = mkHomeConfig (args // {system = "x86_64-linux";});
      "${args.name}-aarch64" = mkHomeConfig (args // {system = "aarch64-linux";});
    };

    # ── Darwin (nix-darwin + home-manager) ──────────────────────────────────
    # Darwin always includes GUI: nix-darwin implies a graphical macOS environment.
    # Linux profiles use withGui to opt in; macOS never runs headless via nix-darwin.
    mkDarwinConfig = {
      context,
      system,
    }: let
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
      assert profilesValidated;
        darwinLib.lib.darwinSystem {
          inherit system;
          specialArgs = mkSpecialArgs system context;
          modules = [
            ./system/darwin.nix
            hmModule
            {
              nixpkgs.pkgs = pkgsFor system;
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = false;
                backupFileExtension = "bk";
                extraSpecialArgs = mkSpecialArgs system context;
                users.${user.username} = {
                  imports = mkProfile {
                    inherit context system;
                    tier = "dev";
                    withGui = true;
                  };
                };
              };
            }
          ];
        };
  in {
    # ── homeConfigurations ──────────────────────────────────────────────────
    # Bootstrap: nix run home-manager -- switch --flake ~/.nix-config#<name>
    # After first apply: home-manager switch --flake ~/.nix-config#<name>
    #
    # To add a profile: add an entry to modules/profile-list.nix.
    homeConfigurations =
      nixpkgs.lib.concatMapAttrs
      (name: axes: mkLinuxPair (axes // {inherit name;}))
      profileList;

    # ── darwinConfigurations ────────────────────────────────────────────────
    # Bootstrap: sudo darwin-rebuild switch --flake ~/.nix-config#<name>
    darwinConfigurations = {
      "personal-darwin" = mkDarwinConfig {
        context = "personal";
        system = "x86_64-darwin";
      };
      "personal-darwin-aarch64" = mkDarwinConfig {
        context = "personal";
        system = "aarch64-darwin";
      };
      "work-darwin" = mkDarwinConfig {
        context = "work";
        system = "x86_64-darwin";
      };
      "work-darwin-aarch64" = mkDarwinConfig {
        context = "work";
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
    # The Nix-specific verification: every Linux activation package builds, and
    # the generated docs match their sources.
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
    #
    # Covers every system, but the contents differ by platform, and not
    # arbitrarily: `activation-*` is derived from `homeConfigurations`, which
    # only exist for Linux (macOS goes through `darwinConfigurations`), so
    # darwin is left with the platform-independent checks: currently
    # `docs-drift`. That is thin, but it is not nothing: before this output
    # covered darwin at all, `nix flake check` on a Mac skipped `checks`
    # entirely and passed, so a green local check meant only that the flake
    # evaluated.
    #
    # The darwin system closures are deliberately NOT included here. CI's
    # build-darwin job already builds all four, and adding them would turn
    # `just check`: the command CONTRIBUTING tells you to run before every PR
    #: into a multi-minute build. Real assertion-level darwin coverage comes
    # from the nmt-* entries below instead: an eval-only test harness that
    # never builds a real package, so it stays cheap even on every darwin
    # system.
    checks = nixpkgs.lib.genAttrs allSystems (
      system: let
        # pkgsFor, not mkPkgs: mkPkgs always imports the rolling nixpkgs, which
        # has dropped x86_64-darwin, so any darwin check evaluated through it
        # dies with "Nixpkgs 26.11 has dropped support for x86_64-darwin"
        # before it can run. pkgsFor routes that one system to the pinned
        # nixpkgs-darwin input. Latent while `checks` was Linux-only.
        pkgs = pkgsFor system;
        homeConfigsForSystem =
          nixpkgs.lib.filterAttrs
          (
            _: cfg:
              cfg.activationPackage.system or null == system
          )
          self.homeConfigurations;
        # nmt's own `build` attrset already includes an `all` aggregate
        # (build.all), which surfaces here as nmt-all: a single check that
        # depends on every individual nmt test.
        nmtBuild = (mkNmtTests system).build;
      in
        (nixpkgs.lib.mapAttrs'
          (name: cfg: {
            name = "activation-${name}";
            value = cfg.activationPackage;
          })
          homeConfigsForSystem)
        // (nixpkgs.lib.mapAttrs'
          (name: drv: {
            name = "nmt-${name}";
            value = drv;
          })
          nmtBuild)
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
        }
    );
  };
}
