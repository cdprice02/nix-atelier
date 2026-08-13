# Synthetic hardware-configuration.nix, for CI build-verification of the
# NixOS kind only (#5). There is no NixOS hardware in this loop to generate a
# real one from, and this repo's own nixosConfigurations entry ships build-
# verified only: this fixture exists so `nix build` can prove a NixOS config
# evaluates and produces a real system.build.toplevel, not so anything ever
# boots from it. A real consumer points hardwareModule at their own machine's
# real /etc/nixos/hardware-configuration.nix instead.
{
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = false;
}
