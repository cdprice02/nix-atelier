# Config for treefmt-nix (see flake.nix's treefmt-nix input and its
# formatter/devShells/checks wiring). One config, four tools, replacing what
# was previously four independently-invoked tools (alejandra, statix,
# deadnix, markdownlint) across `nix fmt`, .pre-commit-config.yaml, and
# CI's now-removed lint-* jobs.
{ pkgs, ... }:
{
  # Default tree-root detection searches upward for .git/config, which
  # doesn't exist as a directory in a git worktree (.git is a file there
  # pointing at the real gitdir) -- confirmed directly: the wrapper failed
  # with "could not find [.git/config]" inside one of this repo's own
  # issue-<N> worktrees (see .claude/skills/nix-atelier/SKILL.md's PR
  # workflow, one worktree per issue -- a real, recurring case here, not an
  # edge case). flake.nix is a plain file, unaffected by that, and every
  # checkout of this repo has exactly one.
  projectRootFile = "flake.nix";
  # treefmt-nix's own `programs.nixfmt` formatter defaults its package to
  # bare `pkgs.nixfmt` -- confirmed directly, not assumed, since this is
  # exactly the trap #54 already documented: on the pinned nixpkgs-darwin
  # input this flake sources every formatter from (see flake.nix's
  # treefmt-nix input comment), bare `nixfmt` resolves to the OLD classic
  # 0.6.0 formatter, a genuinely different tool from `nixfmt-rfc-style`
  # (1.1.0 on this same pin). The override below is load-bearing, not
  # decorative.
  programs.nixfmt = {
    enable = true;
    package = pkgs.nixfmt-rfc-style;
  };
  programs.statix.enable = true;
  programs.deadnix.enable = true;
  # markdownlint has no treefmt-nix equivalent (checked: its markdown
  # options are mdformat/prettier/rumdl/remarkjs). mdformat is treefmt-nix's
  # own canonical markdown formatter and needed no extra packaging, unlike
  # the alternatives (rumdl isn't in this repo's nixpkgs pin at all;
  # prettier's usual package path was removed from nixpkgs). Real behavior
  # change from markdownlint, not a drop-in: different default style, so the
  # first run reformats every tracked .md file for real.
  #
  # Plain `pkgs.mdformat` ships with zero plugins by default -- confirmed by
  # trying it first: it silently ate .claude/skills/*/SKILL.md's YAML
  # frontmatter, turning the `---`-delimited block into a horizontal rule
  # plus a heading, which would have broken skill discovery (name/
  # description are parsed as real frontmatter, not prose). mdformat-gfm
  # and mdformat-tables are the same kind of correctness fix for GitHub-
  # flavored tables (this repo's docs use them extensively) rather than
  # relying on mdformat's plain-CommonMark defaults getting them right by
  # accident.
  #
  # `plugins`, not a manual `package = pkgs.mdformat.withPlugins (...)`
  # override: treefmt-nix's own mdformat module computes `finalPackage`
  # (what actually lands in treefmt.toml) from this option internally, and
  # discards a hand-wrapped `package` override entirely -- confirmed by
  # testing the `package` override first, which built successfully and
  # even reported the right `programs.mdformat.package.outPath` back, but
  # `finalPackage` (and the real rendered treefmt.toml) still pointed at
  # plain unplugged mdformat regardless.
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
    # immediately drift from what was just committed -- confirmed directly:
    # first pass here (no excludes) reformatted them, and docs-drift failed
    # on the very next `just check` because the two disagreed permanently.
    excludes = [
      "docs/profiles.md"
      "docs/tools.md"
    ];
  };
}
