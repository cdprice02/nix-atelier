{ pkgs, system, user, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  users.users.${user.username} = {
    isNormalUser = true;
    description  = user.username;
    extraGroups  = [ "wheel" "networkmanager" ];
    shell        = pkgs.zsh;
  };

  programs.zsh.enable = true;

  system.stateVersion = "23.11";
}
