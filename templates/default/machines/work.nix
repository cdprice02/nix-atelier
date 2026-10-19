# Machine-specific settings for the `work` config in flake.nix: anything
# too niche for a nix-atelier feature, or that only makes sense on this one
# machine. A plain Home Manager module apart from the outer function, so
# add any option here the way you would in home.nix.
#
# The outer function takes nix-atelier's hm-compat.nix from the flake input
# (flake.nix passes it), because the git identity options are named
# differently on the frozen x86_64-darwin release.
{ hmCompatPath }:
{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let
  compat = import hmCompatPath { inherit lib options; };
in
{
  # force = true is required: nix-atelier sets your identity at a normal
  # priority, so an equal-priority override without force conflicts
  # instead of winning.
  programs.git = compat.gitIdentity {
    name = "Your Work Name";
    email = "you@work.example.com";
    force = true;
  };

  home.packages = with pkgs; [
    hello # stand-in for a tool only this machine needs
  ];

  home.sessionVariables = {
    MY_WORK_ONLY_VAR = "some-machine-specific-value";
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/bin" # e.g. scripts synced here by another tool
  ];
}
