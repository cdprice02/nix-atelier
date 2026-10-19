# The module itself comes from the nix-index-database input (see
# featureInputModules in flake.nix); importing it enables programs.nix-index,
# whose shell integration names the package behind an unknown command.
{
  programs.nix-index-database.comma.enable = true;
}
