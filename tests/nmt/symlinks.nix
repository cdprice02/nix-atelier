# Out-of-store agent config symlinks (issue #53): claude.nix and copilot.nix
# each own one symlink, neither gated on anything -- both are in the default
# full/headless fixture, so this runs against the harness's baseline instance.
#
# The expected target embeds base.nix's own homeDirectory derivation
# ("/Users/<user>" on darwin, "/home/<user>" on Linux, mkForce'd off
# pkgs.stdenv.isDarwin, which in turn comes from the harness's `system`) --
# computed here in Nix, not read from $HOME at assertion-script runtime,
# since the build sandbox's real $HOME has no relation to the fixture's
# declared home.homeDirectory.
{system}: let
  isDarwin = builtins.match ".*-darwin" system != null;
  homeDir =
    if isDarwin
    then "/Users/yourusername"
    else "/home/yourusername";
in {
  agent-symlinks-present = {
    nmt.description = ''
      features/claude.nix and features/copilot.nix each point their symlink
      at this repo's own config/ submodules via mkOutOfStoreSymlink. Confirms
      both resolve to the expected target rather than, say, silently pointing
      at the Nix store (which would defeat the whole point of an
      out-of-store symlink for a git-managed tool config).
    '';
    nmt.script = ''
      # mkOutOfStoreSymlink is two hops: home-files/.claude -> a Nix-store
      # "hm_claude" symlink -> the real out-of-store target, which doesn't
      # exist on disk in this sandbox (no /Users/yourusername here). Plain
      # `readlink` just reads a symlink's text target with no existence
      # requirement, unlike `readlink -f` (GNU: all but the last path
      # component must exist) -- two single-hop reads instead of a
      # canonicalizing one.
      assertLinkExists home-files/.claude
      hop1="$(readlink "$(_abs home-files/.claude)")"
      target="$(readlink "$hop1")"
      [[ "$target" == "${homeDir}/.nix-atelier/config/claude" ]] \
        || fail ".claude should resolve to ${homeDir}/.nix-atelier/config/claude, got: $target (via $hop1)"

      assertLinkExists home-files/.copilot
      hop1="$(readlink "$(_abs home-files/.copilot)")"
      target="$(readlink "$hop1")"
      [[ "$target" == "${homeDir}/.nix-atelier/config/copilot" ]] \
        || fail ".copilot should resolve to ${homeDir}/.nix-atelier/config/copilot, got: $target (via $hop1)"
    '';
  };
}
