# Overrides base.nix's git identity for this one machine, and installs a
# couple of packages that don't belong in any public feature -- too niche,
# or specific to a workflow only this machine runs.
#
# Resolves nix-atelier's hm-compat.nix via $HOME rather than a hardcoded
# absolute path, so this file works unmodified on any machine that clones
# nix-atelier to the conventional ~/.nix-atelier location.
{
  lib,
  options,
  pkgs,
  ...
}: let
  compat = import (builtins.getEnv "HOME" + "/.nix-atelier/modules/lib/hm-compat.nix") {inherit lib options;};
in {
  # force = true is required: base.nix sets its own identity at a real
  # priority (compat.gitIdentity), not mkDefault, so an equal-priority
  # override without force would conflict rather than win.
  programs.git = compat.gitIdentity {
    name = "Your Workstation Name";
    email = "you@workstation.example.com";
    force = true;
  };

  home.packages = with pkgs; [
    hello # stand-in: whatever this one machine needs that isn't worth a public feature
  ];
}
