# Overrides base.nix's git identity for this one machine, and installs a
# couple of packages that don't belong in any public feature -- too niche,
# or specific to a workflow only this machine runs.
#
# A module factory, not a plain module: needs nix-atelier's own
# hm-compat.nix (for gitIdentity's force-override helper), resolved through
# a path the consuming flake threads in -- typically
# "${nix-atelier}/modules/lib/hm-compat.nix", the flake input's own store
# path -- rather than a hardcoded $HOME/.nix-atelier checkout, which breaks
# for anyone consuming nix-atelier as a pure flake input with no local
# checkout at all.
{ hmCompatPath }:
{
  lib,
  options,
  pkgs,
  ...
}:
let
  compat = import hmCompatPath { inherit lib options; };
in
{
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
