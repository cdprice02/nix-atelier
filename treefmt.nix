# Config for treefmt-nix (see flake.nix's treefmt-nix input and its
# formatter/devShells/checks wiring). One config, four tools, replacing what
# was previously four independently-invoked tools (alejandra, statix,
# deadnix, markdownlint) across `nix fmt`, .pre-commit-config.yaml, and
# CI's now-removed lint-* jobs.
{ pkgs, ... }:
{
  # Default tree-root detection searches upward for .git/config, which
  # doesn't exist as a directory in a git worktree (.git is a file there
  # pointing at the real gitdir), and this repo's own PR workflow is one
  # worktree per issue -- a real, recurring case here, not an edge case.
  # flake.nix is a plain file, unaffected by that, and every checkout of
  # this repo has exactly one.
  projectRootFile = "flake.nix";
  # treefmt-nix's own `programs.nixfmt` formatter defaults its package to
  # bare `pkgs.nixfmt`, the trap #54 documented: on the pinned nixpkgs-darwin
  # input this flake sources every formatter from, bare `nixfmt` resolves to
  # the OLD classic 0.6.0 formatter, a genuinely different tool from
  # `nixfmt-rfc-style` (1.1.0 on this same pin). The override below is
  # load-bearing, not decorative.
  programs.nixfmt = {
    enable = true;
    package = pkgs.nixfmt-rfc-style;
  };
  programs.statix.enable = true;
  programs.deadnix.enable = true;
  # Scoped to .github/workflows/*.yml by the module's own default includes
  # (also .gitea/.forgejo, neither present here). Nothing else in the repo
  # looks like a workflow file, so no override needed.
  programs.actionlint.enable = true;
  # Default includes (*.yaml, *.yml) cover every tracked YAML in the repo,
  # not just workflows: the ISSUE_TEMPLATE forms, dependabot.yml,
  # .pre-commit-config.yaml, .sops.yaml. All plain, ordinary YAML with
  # nothing workflow-specific about it, so there's no reason to scope this
  # one down to .github/workflows the way actionlint necessarily is.
  programs.yamllint = {
    enable = true;
    # Checked directly: yamllint's stock "default" ruleset flags 80-char
    # line-length as a hard error across every workflow file (this repo's
    # prose comments routinely run longer, same as .nix and .md), plus
    # "truthy value" on every workflow's own `on:` key, a GitHub Actions
    # idiom, not a mistake. Both are real friction, not a real bug. yamllint
    # ships "relaxed" as its own answer to exactly this: keeps genuine
    # correctness rules (duplicate keys, trailing whitespace, missing final
    # newline) at error level, downgrades style-only rules to non-blocking
    # warnings, and disables document-start/truthy/comments-indentation
    # outright rather than a bespoke ruleset assembled by hand here.
    settings.extends = "relaxed";
  };
  # markdownlint has no treefmt-nix equivalent (checked: its markdown
  # options are mdformat/prettier/rumdl/remarkjs). mdformat is treefmt-nix's
  # own canonical markdown formatter and needed no extra packaging, unlike
  # the alternatives (rumdl isn't in this repo's nixpkgs pin at all;
  # prettier's usual package path was removed from nixpkgs). Real behavior
  # change from markdownlint, not a drop-in: different default style, so the
  # first run reformats every tracked .md file for real.
  #
  # Plain `pkgs.mdformat` ships with zero plugins by default, and silently
  # eats .claude/skills/*/SKILL.md's YAML frontmatter without them (turns the
  # `---`-delimited block into a horizontal rule plus a heading, which breaks
  # skill discovery: name/description are parsed as real frontmatter, not
  # prose). mdformat-frontmatter fixes that; mdformat-gfm and mdformat-tables
  # are the same kind of correctness fix for GitHub-flavored tables (this
  # repo's docs use them extensively) rather than relying on mdformat's
  # plain-CommonMark defaults getting them right by accident.
  #
  # `plugins`, not a manual `package = pkgs.mdformat.withPlugins (...)`
  # override: treefmt-nix's own mdformat module computes `finalPackage`
  # (what actually lands in treefmt.toml) from this option internally, and
  # discards a hand-wrapped `package` override entirely -- the rendered
  # treefmt.toml still points at plain unplugged mdformat regardless of what
  # `package` is set to.
  programs.mdformat = {
    enable = true;
    plugins = ps: [
      ps.mdformat-frontmatter
      ps.mdformat-gfm
      ps.mdformat-tables
    ];
    # number = true (mdformat's own --number): its default flattens every
    # ordered list to "1." "1." "1." (valid CommonMark, browsers/GitHub
    # still render it 1/2/3 -- but it's a real, visible style change from
    # what every ordered list in this repo already looked like under
    # markdownlint). Keeping literal incremental numbers is the smaller
    # diff and matches the prior convention rather than defaulting into
    # mdformat's opinion.
    settings.number = true;
    # docs/profiles.md and docs/tools.md are generated (modules/docs-gen.nix),
    # not hand-written -- their canonical formatting is whatever that
    # generator emits, checked byte-for-byte against the committed file by
    # flake.nix's own docs-drift check. mdformat-tables pads GFM table
    # columns; docs-gen.nix's own templates render tight ones. Letting
    # mdformat touch these files would make every `just docs` regeneration
    # immediately drift from what was just committed and fail docs-drift.
    excludes = [
      "docs/profiles.md"
      "docs/tools.md"
    ];
  };
}
