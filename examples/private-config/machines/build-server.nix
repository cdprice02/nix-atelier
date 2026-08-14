# This machine runs the `minimal` tier (set in its own flake.nix's
# configs.home.<name>.tier, not here) plus whatever this file adds directly:
# a package worth having on a
# headless build machine but not worth a public feature of its own -- too
# small, too specific to this one machine's job to justify a shared feature
# module.
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    borgbackup # this machine's own backup job shells out to it
  ];
}
