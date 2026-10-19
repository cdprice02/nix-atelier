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

      # One entry per machine, named however you like: the name is what you
      # switch to (`nh home switch -c full .`). Delete the ones you don't
      # need. See modules/features.nix in nix-atelier for the feature list,
      # and lib/mkConfigs.nix for every field configs.home/.darwin/.nixos
      # accepts.
      configs = {
        home.full = {
          tier = "full"; # or "minimal"
          system = "x86_64-linux"; # or aarch64-linux / x86_64-darwin / aarch64-darwin
          # withGui = true;
        };

        # A second machine with its own features, plus its own settings
        # from machines/work.nix. Files inside this repo need no --impure;
        # `git add` them, since a flake only sees tracked files.
        home.work = {
          system = "x86_64-linux";
          features.exclude = [ "k8s" ];
          extraConfig = {
            imports = [
              (import ./machines/work.nix {
                hmCompatPath = "${nix-atelier}/modules/lib/hm-compat.nix";
              })
            ];
            # Secrets: see secrets/work.yaml.example and .sops.yaml.example.
            # atelier.sops = {
            #   file = "${self}/secrets/work.yaml";
            #   secrets = [ "GITHUB_PERSONAL_ACCESS_TOKEN" ];
            # };
          };
        };

        # A headless machine: the tier is set here, extra packages in its
        # own machines/<name>.nix.
        # home.server = {
        #   tier = "minimal";
        #   system = "aarch64-linux";
        # };

        # darwin.laptop = {
        #   system = "aarch64-darwin"; # or x86_64-darwin
        # };
      };

      # Everything below is optional and can be left out entirely. These
      # apply to every config above; a config's own `features` block adds to
      # these rather than replacing them.
      # features = {
      #   extra = [ "lang-rust" ];
      #   exclude = [ ];
      #   # Absolute paths to modules outside this repo; needs --impure.
      #   extraModulePaths = [ ];
      #   # darwin/nixos only: extends system/darwin.nix or system/nixos.nix.
      #   extraSystemModulePaths = [ ];
      # };
    };
}
