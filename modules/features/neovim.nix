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

  home.packages = with pkgs; [
    neovim
    # nvim-treesitter compiles its parsers locally: the tree-sitter CLI
    # generates them (required on its main branch, Neovim 0.12+) and a C
    # compiler builds them (required on both branches). telescope-fzf-native
    # builds its sorter with make and the same compiler.
    tree-sitter
    gcc
    gnumake
  ];

  # base.nix's programs.vim.defaultEditor sets EDITOR/VISUAL=vim for every
  # profile, this feature or not; override both only where Neovim is
  # actually installed.
  home.sessionVariables = {
    EDITOR = lib.mkForce "nvim";
    VISUAL = lib.mkForce "nvim";
  };
}
