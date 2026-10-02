# Neovim, with its config as the config/nvim submodule (cdprice02/nvim-config)
# symlinked to ~/.config/nvim -- the same live-editable pattern as claude.nix
# and copilot.nix. Plugins are the config's own business (lazy.nvim, pinned
# by its committed lazy-lock.json); everything a plugin shells out to
# (language servers, formatters, tree-sitter, a C compiler) comes from Nix
# here instead, so there is no Mason.
#
# Plain home.packages rather than programs.neovim deliberately: that module
# generates its own init.lua under ~/.config/nvim, which would collide with
# the symlinked directory.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.file.".config/nvim" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.atelier.checkoutPath}/config/nvim";
  };

  home.packages =
    with pkgs;
    [
      neovim
      # nvim-treesitter compiles its parsers locally: the tree-sitter CLI
      # generates them (required on its main branch, Neovim 0.12+) and a C
      # compiler builds them (required on both branches). telescope-fzf-native
      # builds its sorter with make and the same compiler. The compiler is
      # per-platform (below); make and the CLI are not.
      tree-sitter
      gnumake
      # Language servers not already provided by a lang-* feature (those
      # bring rust-analyzer, ruff and nixd). The Neovim config enables each
      # one by name; see its lua/cdprice/lazy/lsp.lua.
      basedpyright
      lua-language-server
      # Formatters conform.nvim runs on save (lua/cdprice/lazy/format.lua),
      # beyond the ruff/nixfmt/rustfmt the lang-* features already install.
      prettierd
      stylua
      shfmt
      taplo # also the TOML language server
      # Language servers for the everyday non-core languages: JSON/HTML/CSS
      # (one package), YAML, Markdown, shell (bash-language-server runs
      # shellcheck itself), and C for QMK keymaps.
      vscode-langservers-extracted
      yaml-language-server
      marksman
      bash-language-server
      shellcheck
      clang-tools
    ]
    # A C compiler only where the platform doesn't already have one. On
    # Linux nothing is guaranteed, so Nix provides gcc. On macOS the Xcode
    # Command Line Tools put clang at /usr/bin/cc, and shipping gcc here
    # cost 297 MB and shadowed that cc: the Nix profile precedes /usr/bin
    # on PATH, so every `cc` invocation on the machine -- native Python
    # wheels, node-gyp, cargo build scripts -- silently changed compiler
    # family on a platform whose SDK expects clang. The tradeoff is that a
    # fresh macOS with no Command Line Tools installed has no compiler for
    # tree-sitter to call; `xcode-select --install` is the fix, and it is
    # already a prerequisite for much of the surrounding toolchain.
    ++ lib.optional pkgs.stdenv.isLinux pkgs.gcc;

  # base.nix's programs.vim.defaultEditor sets EDITOR/VISUAL=vim for every
  # profile, this feature or not; override both only where Neovim is
  # actually installed.
  home.sessionVariables = {
    EDITOR = lib.mkForce "nvim";
    VISUAL = lib.mkForce "nvim";
  };
}
