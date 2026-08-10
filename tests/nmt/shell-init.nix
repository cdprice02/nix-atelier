# Per-shell init contracts (issue #52): zsh, bash, and fish are deliberately
# *not* configured identically (base.nix and lang-node.nix explain why in
# prose). These pin each asymmetry as an assertion so a change to any of them
# is a deliberate test edit, not a silent drift.
{
  fish-omits-secrets-and-fnm = {
    nmt.description = ''
      fish is never a login shell here (base.nix says so explicitly), so it
      gets neither the POSIX secrets/env source nor fnm's per-shell `eval`.
      Also confirms fish keeps HM's native runtime integration for
      zoxide/fzf/direnv rather than picking up the zsh/bash static-capture
      pattern (mkInit in shell-tools.nix).
    '';
    nmt.script = ''
      assertFileContains  home-files/.config/fish/config.fish 'caret.fish'
      assertFileNotRegex  home-files/.config/fish/config.fish 'secrets/env'
      assertFileNotRegex  home-files/.config/fish/config.fish 'fnm'
      assertFileNotRegex  home-files/.config/fish/config.fish 'hm-shell-init'
    '';
  };

  fish-omits-word-navigation-bindkeys = {
    nmt.description = ''
      The Alt/Home/End bindkeys are zsh-only (bound via bindkey, a zsh
      builtin); fish and bash never had an equivalent added.
    '';
    nmt.script = ''
      assertFileNotRegex home-files/.config/fish/config.fish 'backward-word'
    '';
  };

  zshenv-puts-nix-on-path-first = {
    nmt.description = ''
      envExtra -> .zshenv, sourced before .zshrc, so Nix is on PATH before
      any tool-init hook runs. Load-bearing ordering: nixProfileInit must
      stay in envExtra, not initContent.
    '';
    nmt.script = ''
      assertFileContains home-files/.zshenv 'nix-profile'
      assertFileNotRegex home-files/.zshrc  'nix-profile'
    '';
  };

  zsh-compinit-cache-fires = {
    nmt.description = ''
      Regression guard: this cache was once committed in a state where it
      silently never fired (caught only by reading generated output).
    '';
    nmt.script = ''
      assertFileContains home-files/.zshrc 'compinit -C'
      assertFileContains home-files/.zshrc 'zcompdump'
    '';
  };

  zsh-has-secrets-fnm-and-bindkeys = {
    nmt.description = ''
      The positive side of the fish asymmetries above: zsh (a real login
      shell here) gets secrets/env, fnm, and the word-navigation bindkeys.
    '';
    nmt.script = ''
      assertFileContains home-files/.zshrc 'secrets/env'
      assertFileContains home-files/.zshrc 'fnm env --use-on-cd'
      assertFileContains home-files/.zshrc 'backward-word'
    '';
  };

  bash-has-secrets-and-fnm-but-no-bindkeys = {
    nmt.description = ''
      bash gets the same secrets/env + fnm treatment as zsh (it can also be
      a login shell here), but never had the zsh-specific bindkeys added.
    '';
    nmt.script = ''
      assertFileContains home-files/.bashrc 'secrets/env'
      assertFileContains home-files/.bashrc 'fnm env --use-on-cd'
      assertFileNotRegex home-files/.bashrc 'backward-word'
    '';
  };

  static-tool-init-captures-are-sourced = {
    nmt.description = ''
      zsh/bash source a build-time capture of `zoxide/fzf/direnv init`
      (mkInit in shell-tools.nix) instead of running it on every shell
      startup. Asserting the "hm-shell-init-*" derivation name in the
      rendered file (rather than the underlying `... init zsh` text, which
      would also match a live eval) is what actually distinguishes the
      static capture from the eval it replaced.
    '';
    nmt.script = ''
      assertFileContains home-files/.zshrc 'hm-shell-init-zoxide-zsh'
      assertFileContains home-files/.zshrc 'hm-shell-init-direnv-zsh'
      assertFileContains home-files/.zshrc 'hm-shell-init-fzf-zsh'

      assertFileContains home-files/.bashrc 'hm-shell-init-zoxide-bash'
      assertFileContains home-files/.bashrc 'hm-shell-init-direnv-bash'
      assertFileContains home-files/.bashrc 'hm-shell-init-fzf-bash'
    '';
  };

  fzf-zsh-has-zle-guard = {
    nmt.description = ''
      fzf's zsh init toggles the `zle` option, which warns
      ("can't change option: zle") in interactive-but-non-zle contexts.
      zsh guards the source behind an `if [[ $options[zle] = on ]]`; bash
      has no such option and must not carry the guard.
    '';
    nmt.script = ''
      assertFileContains home-files/.zshrc  'options[zle]'
      assertFileNotRegex home-files/.bashrc 'options\[zle\]'
    '';
  };
}
