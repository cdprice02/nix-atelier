# Sibling of claude.nix: each owns one agent's config symlink. Neither is
# gated on anything; either can be dropped via excludeFeatures.
{ config, ... }:
{
  # Submodule under config/ symlinked into HOME so tools find it at the
  # expected path. mkOutOfStoreSymlink keeps it live-editable (not copied
  # into the Nix store), which is required for a git-managed tool config.
  home.file.".copilot" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.atelier.checkoutPath}/config/copilot";
  };
}
