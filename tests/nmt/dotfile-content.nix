# Dotfile content assertions (issue #42): a config can build cleanly and
# still render the wrong thing. Two precedents motivate this file: the
# cached-compinit logic (tests/nmt/shell-init.nix) once shipped silently
# inert, and a shallow merge once produced a darwin generation with *no git
# config at all* -- `programs.git.enable` had been clobbered, and the build
# was green. Folded into nmt rather than the standalone `checks` grep
# originally proposed in #42, since nmt already builds the same tree.
{
  npmrc-has-writable-prefix = {
    nmt.description = ''
      modules/env.nix exists specifically to give npm a writable global
      prefix outside the Nix store; confirm the rendered .npmrc still
      carries it.
    '';
    nmt.script = ''
      assertFileContains home-files/.npmrc 'prefix='
      assertFileContains home-files/.npmrc '.npm-global'
    '';
  };

  git-config-survives-multi-fragment-merge = {
    nmt.description = ''
      base.nix builds programs.git from four independent lib.mkMerge
      fragments (enable+includes+ignores, identity, core/pull/push
      settings, delta's pager) specifically because a shallow `//` merge
      once dropped one of them entirely -- programs.git.enable disappeared
      and the build stayed green. Assert all four surface together, so a
      regression to `//` or a dropped fragment fails loudly instead of
      quietly.
    '';
    nmt.script = ''
      assertFileContains home-files/.config/git/config '[user]'
      assertFileContains home-files/.config/git/config 'name = "Your Name"'
      assertFileContains home-files/.config/git/config 'defaultBranch = "main"'
      assertFileContains home-files/.config/git/config 'gitalias.txt'
      assertFileContains home-files/.config/git/config 'delta'
    '';
  };
}
