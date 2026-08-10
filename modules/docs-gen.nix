# Pure-Nix generator for docs/profiles.md and docs/tools.md, consumed by
# flake.nix's `packages.<system>.docs-*` (buildable, for `just docs`) and
# `checks.<system>.docs-drift` (fails CI if the committed file disagrees).
# No fallback bash/python script; matches this repo's own "Nix is the only
# path" rule (CLAUDE.md).
#
# Prose sections (profile-choosing guidance, "Customizing your machine", the
# Module composition table) are literal strings here, not derived from data.
# They're editorial content, not enumerable facts. Once a doc is
# generated, ALL edits go through its generator, including these "hand
# maintained" parts: editing the committed docs/*.md directly gets
# overwritten on the next `just docs` / CI regeneration.
{lib}: {
  tiers,
  toolCatalog,
  homeConfigNames,
  darwinConfigNames,
}: let
  # ═══════════════════════════════════════════════════════════════════════
  # docs/profiles.md
  # ═══════════════════════════════════════════════════════════════════════
  # Editorial ordering (bootstrap-complexity progression), not attrNames'
  # arbitrary sort; validated against tiers' real keys below.
  tierOrder = ["minimal" "full"];
  tierOrderOk =
    lib.throwIf
    (lib.sort lib.lessThan tierOrder != lib.sort lib.lessThan (lib.attrNames tiers))
    "docs-gen.nix: tierOrder (${toString tierOrder}) doesn't match tiers' keys (${toString (lib.attrNames tiers)}); update tierOrder"
    true;

  linuxArches = ["x86_64-linux" "aarch64-linux"];
  mkHomeConfigName = tierName: withGui: arch:
    tierName
    + (lib.optionalString withGui "-gui")
    + (lib.optionalString (arch == "aarch64-linux") "-aarch64");

  # Same loop flake.nix's own homeConfigMatrix runs, over the same tierOrder
  # used for display below: if the two ever disagree about which names exist,
  # this throws rather than silently rendering a table that doesn't match the
  # real homeConfigurations attrset (same "fail eval, don't drift silently"
  # idiom the darwin guard below uses).
  expectedHomeConfigNames =
    lib.concatMap (
      tierName:
        lib.concatMap (
          withGui: map (arch: mkHomeConfigName tierName withGui arch) linuxArches
        ) [false true]
    )
    tierOrder;
  homeConfigNamesOk =
    lib.throwIf
    (lib.sort lib.lessThan expectedHomeConfigNames != lib.sort lib.lessThan homeConfigNames)
    "docs-gen.nix: computed homeConfigurations names (${toString expectedHomeConfigNames}) don't match the real ones (${toString homeConfigNames}); flake.nix's homeConfigMatrix and this file's mkHomeConfigName have drifted apart"
    true;

  expectedDarwinNames = ["full-darwin" "full-darwin-aarch64"];
  darwinNamesOk =
    lib.throwIf
    (lib.sort lib.lessThan darwinConfigNames != lib.sort lib.lessThan expectedDarwinNames)
    "docs-gen.nix: darwinConfigurations names changed (now ${toString darwinConfigNames}); update the hardcoded darwin table in modules/docs-gen.nix to match"
    true;

  describeHomeConfig = tierName: withGui: let
    base =
      if tierName == "minimal"
      then "core only"
      else "core + every feature";
  in
    base + (lib.optionalString withGui " + gui-linux");

  useForHomeConfig = tierName: withGui:
    if tierName == "minimal" && !withGui
    then "Bootstrap or low-resource machine"
    else if tierName == "minimal" && withGui
    then "Minimal desktop Linux"
    else if withGui
    then "Full desktop Linux"
    else "Full dev environment: Linux / WSL2";

  homeProfileRow = tierName: withGui: arch: let
    name = mkHomeConfigName tierName withGui arch;
  in "| \`${name}\` | ${describeHomeConfig tierName withGui} | ${useForHomeConfig tierName withGui} |\n";
  homeProfileRows =
    lib.concatStrings
    (lib.concatMap (
        tierName:
          lib.concatMap (
            withGui: map (arch: homeProfileRow tierName withGui arch) linuxArches
          ) [false true]
      )
      tierOrder);

  darwinArchLabel = suffix:
    if suffix == "-aarch64"
    then "Apple Silicon"
    else "Intel";
  darwinProfileRow = suffix: "| \`full-darwin${suffix}\` | macOS (${darwinArchLabel suffix}) |\n";
  darwinProfileRows =
    lib.concatStrings
    (map darwinProfileRow ["" "-aarch64"]);

  profilesMd = assert tierOrderOk;
  assert homeConfigNamesOk;
  assert darwinNamesOk; ''
    # Profiles

    ## Choosing a profile

    Every profile is `tier` (`minimal` or `full`) crossed with `gui` (on or
    off) crossed with CPU architecture. There's no third axis to reason
    about, and nothing to configure beyond that: `full` is every feature this
    repo has, `minimal` is none of them.

    **New machine?** Start with `minimal` to bootstrap quickly: it installs
    only the base tools needed to get Nix and home-manager working. Once
    stable, switch to `full` for the complete dev toolchain.

    **Daily driver?** Use `full`: Rust, Node, Python, AWS, Kubernetes, tmux,
    Claude Code, and everything else in `modules/features.nix`.

    **Desktop Linux?** Add `-gui`: adds Obsidian, Alacritty, and VS Code.

    **macOS?** Use `full-darwin` (Intel) or `full-darwin-aarch64` (Apple
    Silicon): GUI is always included on Darwin, and there is no `minimal`
    Mac config.

    ---

    Profiles are composed from three axes by `mkProfile` in `flake.nix`. You
    never manually list modules.

    ```text
    tier    : ${lib.concatStringsSep " | " tierOrder}
    withGui : false | true  (auto-selects gui-linux or gui-darwin)
    system  : x86_64-linux | aarch64-linux | x86_64-darwin | aarch64-darwin
    ```

    `tier` expands into a set of named features: `minimal` is `[]`, `full` is
    every key in `modules/features.nix`, so a new feature joins `full`
    automatically with no list to maintain. `user.nix` can add features
    beyond a machine's tier via `extraFeatures`, or drop specific ones via
    `excludeFeatures` — see `user.nix.example`.

    ## Module composition

    Hand-maintained, not generated (below the per-profile tables).

    | Module | Included when |
    |--------|--------------|
    | `base.nix` ("core") | always |
    | `env.nix` | always |
    | every `features/*.nix` | tier = full, or named in `extraFeatures`, minus anything in `excludeFeatures` |
    | `extraModulePaths` entries | always, if set in `user.nix` (private, machine-specific modules) |
    | `gui-linux.nix` | withGui = true, Linux |
    | `gui-darwin.nix` | withGui = true, Darwin (always on macOS) |

    `minimal` gets only `core` + `env`: no shell comfort tools, no language
    toolchains, no tmux. It keeps `jq`/`wget`/`git-lfs`/`rsync`/`tree`/`ncdu`/`htop`
    in `core` itself: bootstrap/scripting/ops utilities, not comfort tools, so
    "minimal" means lean rather than feature-free.

    ## homeConfigurations (Linux / WSL2)

    Each profile is built for both `x86_64-linux` and `aarch64-linux`. The `aarch64` variant has a `-aarch64` suffix.

    | Profile | Modules | Use for |
    |---------|---------|---------|
    ${homeProfileRows}
    Bootstrap:
    ```sh
    nix run home-manager -- switch --flake ~/.nix-atelier#full --impure -b bk
    # After first apply, home-manager is on PATH:
    home-manager switch --flake ~/.nix-atelier#full --impure -b bk
    ```

    ## darwinConfigurations (macOS)

    Darwin always includes GUI (`gui-darwin.nix`) and is always the `full` tier.

    | Profile | Use for |
    |---------|---------|
    ${darwinProfileRows}
    **Pick by CPU, not preference.** `uname -m` prints `arm64` for Apple
    Silicon, `x86_64` for Intel. The two are not interchangeable: the Intel
    config builds against a pinned nixpkgs 25.05 (nixpkgs-unstable has dropped
    x86_64-darwin), while the Apple Silicon config rides the same rolling inputs
    as Linux.

    Bootstrap: `darwin-rebuild` does not exist until after the first apply, so
    the first one runs nix-darwin straight from the flake:
    ```sh
    # Apple Silicon
    sudo nix --extra-experimental-features "nix-command flakes" \
      run nix-darwin -- switch --flake ~/.nix-atelier#full-darwin-aarch64 --impure

    # Intel: pinned nix-darwin release, matching this repo's 25.05 pin
    sudo nix --extra-experimental-features "nix-command flakes" \
      run nix-darwin/nix-darwin-25.05 -- switch --flake ~/.nix-atelier#full-darwin --impure
    ```

    Every later apply can just use `just switch`, which appends the right
    suffix for the machine's architecture automatically.

    ## Customizing your machine

    The framework makes most decisions for you; three escape hatches in
    `user.nix` cover the rest — see `user.nix.example` for the exact syntax:

    - `extraFeatures` — add named features (see `modules/features.nix`) on
      top of a machine's tier, e.g. `minimal` plus just `tmux`.
    - `excludeFeatures` — drop features regardless of tier, e.g. `full`
      without `lang-rust`.
    - `extraModulePaths` — absolute paths to private, machine-specific
      home-manager modules that live outside this repo entirely (identity
      overrides, extra secrets, anything that shouldn't be public).

    Regenerate this file and commit the result after any change that affects
    it (a new feature, a renamed tier); the `docs-drift` check fails
    otherwise, since this table is generated from the same data `flake.nix`
    builds `homeConfigurations` from:
    ```sh
    just docs
    ```
  '';

  # ═══════════════════════════════════════════════════════════════════════
  # docs/tools.md
  # ═══════════════════════════════════════════════════════════════════════

  categoryOrder = [
    "Shell"
    "Fonts"
    "CLI Utilities"
    "Editor"
    "Git"
    "Rust"
    "Node"
    "Python"
    "Data"
    "AWS"
    "Kubernetes"
    "Secrets"
    "Shell Multiplexing"
    "Firmware"
    "Environment Management"
    "AI"
    "GUI (gui-linux / gui-darwin profiles only)"
  ];
  allToolEntries = toolCatalog.entries ++ toolCatalog.nonPackageTools;
  categoryOrderOk =
    lib.throwIf
    (lib.sort lib.lessThan categoryOrder
      != lib.sort lib.lessThan (lib.unique (map (e: e.category) allToolEntries)))
    "docs-gen.nix: categoryOrder doesn't match the categories actually used in tool-catalog.nix; update categoryOrder"
    true;

  toolEntry = e: ''
    ### ${e.key}
    ${e.description} ${e.link}
  '';
  categorySection = category: ''
    ## ${category}

    ${lib.concatStringsSep "\n" (map toolEntry (lib.filter (e: e.category == category) allToolEntries))}
    ---
  '';

  toolsMd = assert categoryOrderOk; ''
    # Tool Reference

    One-liner descriptions and links for every tool managed by this config, organized by category.

    ---

    ${lib.concatStringsSep "\n" (map categorySection categoryOrder)}
  '';

  # Collapse trailing blank lines down to exactly one final newline:
  # string-concatenating multi-line ''...'' blocks naturally accumulates
  # extra trailing newlines at each join point.
  dropTrailingEmpty = lines:
    if lines == [] || lib.last lines != ""
    then lines
    else dropTrailingEmpty (lib.init lines);
  normalizeTrailing = s:
    lib.concatStringsSep "\n" (dropTrailingEmpty (lib.splitString "\n" s)) + "\n";
in {
  profilesMd = normalizeTrailing profilesMd;
  toolsMd = normalizeTrailing toolsMd;
}
