# Pure-Nix generator for docs/profiles.md and docs/tools.md, consumed by
# flake.nix's `packages.<system>.docs-*` (buildable, for `just docs`) and
# `checks.<system>.docs-drift` (fails CI if the committed file disagrees).
# No fallback bash/python script — matches this repo's own "Nix is the only
# path" rule (CLAUDE.md).
#
# Prose sections (profile-choosing guidance, "Adding a new profile", the
# Module composition table) are literal strings here, not derived from data
# — they're editorial content, not enumerable facts. Once a doc is
# generated, ALL edits go through its generator, including these "hand
# maintained" parts: editing the committed docs/*.md directly gets
# overwritten on the next `just docs` / CI regeneration.
{lib}: {
  profiles,
  profileList,
  toolCatalog,
  darwinConfigNames,
}: let
  # ── Guard: fail loudly if darwinConfigurations' names ever change, rather
  # than silently rendering a stale hardcoded table (same "fail eval, don't
  # drift silently" idiom as profilesValidated/profileListValidated). ─────
  expectedDarwinNames = ["personal-darwin" "personal-darwin-aarch64" "work-darwin" "work-darwin-aarch64"];
  darwinNamesOk =
    lib.throwIf
    (lib.sort lib.lessThan darwinConfigNames != lib.sort lib.lessThan expectedDarwinNames)
    "docs-gen.nix: darwinConfigurations names changed (now ${toString darwinConfigNames}) — update the hardcoded darwin table in modules/docs-gen.nix to match"
    true;

  # ═══════════════════════════════════════════════════════════════════════
  # docs/profiles.md
  # ═══════════════════════════════════════════════════════════════════════

  # Editorial ordering (bootstrap-complexity progression), not attrNames'
  # alphabetical sort — validated against profiles.nix's real keys below.
  tierOrder = ["minimal" "dev" "server"];
  tierOrderOk =
    lib.throwIf
    (lib.sort lib.lessThan tierOrder != lib.sort lib.lessThan (lib.attrNames profiles))
    "docs-gen.nix: tierOrder (${toString tierOrder}) doesn't match profiles.nix's keys (${toString (lib.attrNames profiles)}) — update tierOrder"
    true;

  describeModules = {
    context,
    tier,
    withGui,
    ...
  }:
    if tier == "minimal"
    then
      if context == "work"
      then "core + work (cloud only, via work.nix)"
      else "core only"
    else
      "core + ${tier}-tier features"
      + (lib.optionalString (context == "work") " + work")
      + (lib.optionalString withGui " + gui-linux");

  linuxProfileRow = name: axes: "| \`${name}\` | ${describeModules axes} | ${axes.useFor} |\n";
  linuxProfileRows =
    lib.concatStrings
    (lib.mapAttrsToList linuxProfileRow profileList);

  darwinArchLabel = suffix:
    if suffix == "-aarch64"
    then "Apple Silicon"
    else "Intel";
  darwinContextLabel = context:
    if context == "work"
    then "Work"
    else "Personal";
  darwinProfileRow = context: suffix: "| \`${context}-darwin${suffix}\` | ${darwinContextLabel context} macOS (${darwinArchLabel suffix}) |\n";
  darwinProfileRows =
    lib.concatStrings
    (lib.concatMap
      (context: map (suffix: darwinProfileRow context suffix) ["" "-aarch64"])
      ["personal" "work"]);

  profilesMd = assert darwinNamesOk;
  assert tierOrderOk; ''
    # Profiles

    ## Choosing a profile

    **New machine?** Start with `*-minimal` to bootstrap quickly — it installs only the base tools needed to get Nix and home-manager working. Once stable, switch to `work` or `personal` for the full dev toolchain.

    **Daily driver (WSL2/Linux)?** Use `work` or `personal` — these include the full dev tier: Rust, Node, Python, AWS, tmux, and Claude Code.

    **Headless server or CI?** Use `*-server` — stripped-down, no dev toolchain, large tmux scrollback.

    **Desktop Linux?** Use `work-gui` or `personal-gui` — adds Obsidian, Alacritty, and VS Code.

    **macOS?** Use `work-darwin` or `personal-darwin` — GUI is always included on Darwin.

    ---

    Profiles are composed from three axes by `mkProfile` in `flake.nix`. You never manually list modules.

    ```text
    context : personal | work
    tier    : ${lib.concatStringsSep " | " tierOrder}
    withGui : false | true  (auto-selects gui-linux or gui-darwin)
    ```

    `tier` expands into a set of named features via `modules/profiles.nix`, each resolved to a module path via `modules/features.nix`. `user.nix` can add extra features beyond a machine's tier via an `extraFeatures` list — see `user.nix.example`.

    ## Module composition

    Hand-maintained, not generated (below the per-profile tables) — the one row that doesn't reduce to tier/context/withGui cleanly is `cloud.nix`, included both via the `dev` tier *and* independently via `work.nix`'s own `imports`, which isn't expressed as data anywhere (see `modules/docs-gen.nix`'s own note on this).

    | Module | Included when |
    |--------|--------------|
    | `base.nix` ("core") | always |
    | `env.nix` | always |
    | `features/shell-tools.nix` | tier = dev or server |
    | `features/lang-rust.nix`, `lang-node.nix`, `lang-python.nix` | tier = dev |
    | `features/cloud.nix` | tier = dev, or context = work (any tier) |
    | `features/ai.nix` | tier = dev |
    | `features/k8s.nix` | tier = dev |
    | `features/dev-tools.nix` | tier = dev |
    | `features/ops.nix` | tier = server |
    | `work.nix` | context = work |
    | `gui-linux.nix` | withGui = true, Linux |
    | `gui-darwin.nix` | withGui = true, Darwin (always on macOS) |

    `minimal` gets only `core` + `env` — no `shell-tools` (fonts, zoxide/fzf/direnv, ripgrep/bat/eza/etc.) and none of `dev`'s language toolchains. It keeps `jq`/`wget`/`git-lfs` in `core` itself — bootstrap/scripting utilities, not comfort tools, so "minimal" means lean rather than feature-free.

    ## homeConfigurations (Linux / WSL2)

    Each profile is built for both `x86_64-linux` and `aarch64-linux`. The `aarch64` variant has a `-aarch64` suffix.

    | Profile | Modules | Use for |
    |---------|---------|---------|
    ${linuxProfileRows}
    Bootstrap:
    ```sh
    nix run home-manager -- switch --flake ~/.nix-config#work --impure
    # After first apply, home-manager is on PATH:
    home-manager switch --flake ~/.nix-config#work --impure
    ```

    ## darwinConfigurations (macOS)

    Darwin always includes GUI (`gui-darwin.nix`). Tier is always `dev`.

    | Profile | Use for |
    |---------|---------|
    ${darwinProfileRows}
    Bootstrap:
    ```sh
    sudo darwin-rebuild switch --flake ~/.nix-config#personal-darwin --impure
    ```

    ## Adding a new profile

    Add an entry to `modules/profile-list.nix`:

    ```nix
    my-profile = { context = "personal"; tier = "dev"; withGui = false; useFor = "..."; };
    ```

    Then apply with:
    ```sh
    home-manager switch --flake ~/.nix-config#my-profile --impure
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
    "Server Tools"
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
    "docs-gen.nix: categoryOrder doesn't match the categories actually used in tool-catalog.nix — update categoryOrder"
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

  # Collapse trailing blank lines down to exactly one final newline —
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
