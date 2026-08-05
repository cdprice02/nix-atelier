{
  pkgs,
  lib,
  options,
  user,
  ...
}: let
  compat = import ./lib/hm-compat.nix {inherit lib options;};
in {
  # cloud (AWS tooling): present on all work tiers (minimal, dev, server).
  # dev tier also pulls it independently via profiles.nix; the module system
  # dedupes identical module paths across the import graph, so work+dev
  # profiles get it once, not twice.
  imports = [./features/cloud.nix];

  home = {
    # Work SSH stubs: included via the `Include ~/.ssh/config.d/*` in base.nix programs.ssh
    file.".ssh/config.d/work".text = ''
      # Work VPN / jump host: fill in hostnames before use
      # Host work-jump
      #   HostName jump.corp.example.com
      #   User ${user.username}
      #   IdentityFile ~/.ssh/${user.sshKey}
    '';
  };

  # Git identity for work: overrides the personal identity set in base.nix
  programs.git = compat.gitIdentity {
    inherit (user.work) name email;
    force = true;
  };
}
