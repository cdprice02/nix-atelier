{
  description = "My nix-atelier config";

  inputs.nix-atelier.url = "github:cdprice02/nix-atelier";

  outputs =
    { nix-atelier, ... }:
    nix-atelier.lib.mkConfigs {
      identity = {
        username = "yourusername"; # must match your real $USER
        name = "Your Name";
        email = "you@example.com";
        github.user = "yourgithubname";
        # github.id = 12345678; # optional; find yours at https://api.github.com/users/<user>
      };

      # Name your configs whatever you like; the name becomes the flake
      # output you switch to (`home-manager switch --flake .#full`, etc).
      # See modules/features.nix in nix-atelier for the full feature list,
      # and lib/mkConfigs.nix for every field configs.home/.darwin/.nixos
      # accepts.
      configs = {
        home.full = {
          tier = "full"; # or "minimal"
          system = "x86_64-linux"; # or aarch64-linux / x86_64-darwin / aarch64-darwin
          # withGui = true;
        };

        # darwin.full = {
        #   system = "aarch64-darwin"; # or x86_64-darwin
        # };

        # Add as many machines as you like under one identity. Each can
        # carry its own `features`, so they don't all have to want the same
        # things -- e.g. only the machine with cluster access gets k8s:
        # home.work = {
        #   system = "x86_64-linux";
        #   features.exclude = [ "k8s" ];
        # };
      };

      # Everything below is optional and can be left out entirely. These
      # apply to every config above; a config's own `features` block adds to
      # these rather than replacing them.
      # features = {
      #   extra = [ "lang-rust" ];
      #   exclude = [ ];
      #   extraModulePaths = [ ];
      #   # darwin/nixos only: extends system/darwin.nix or system/nixos.nix.
      #   extraSystemModulePaths = [ ];
      # };
    };
}
