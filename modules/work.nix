{
  pkgs,
  lib,
  user,
  ...
}: {
  # AWS tools — present on all work tiers (minimal, dev, server)
  home = {
    packages = with pkgs; [
      awscli2
      aws-vault
    ];

    # Corporate root CA — Linux only; macOS uses the system keychain
    # The PEM file is never committed. Place it manually at ~/.certs/corporate.pem.
    # See docs/bootstrap.md for how to obtain it.
    #
    # combined-ca-bundle.crt = system public CAs + corporate CAs. All vars point here
    # so nix tools, curl, AWS CLI, and Python all trust both public and internal endpoints.
    # NODE_EXTRA_CA_CERTS is append-only (Node bundles its own CAs), so corp.pem suffices.
    sessionVariables = lib.mkIf (!pkgs.stdenv.isDarwin) {
      SSL_CERT_FILE = "$HOME/.certs/combined-ca-bundle.crt";
      NIX_SSL_CERT_FILE = "$HOME/.certs/combined-ca-bundle.crt";
      REQUESTS_CA_BUNDLE = "$HOME/.certs/combined-ca-bundle.crt";
      AWS_CA_BUNDLE = "$HOME/.certs/combined-ca-bundle.crt";
      NODE_EXTRA_CA_CERTS = "$HOME/.certs/corporate.pem";
    };

    # Linux only — macOS trusts corporate certs via system keychain, not this bundle
    activation.mergeCorporateCerts =
      lib.mkIf (!pkgs.stdenv.isDarwin)
      (lib.hm.dag.entryAfter ["writeBoundary"] ''
        $DRY_RUN_CMD mkdir -p "$HOME/.certs"
        if [ -f "$HOME/.certs/corporate.pem" ]; then
          _bundle=$(cat /etc/ssl/certs/ca-certificates.crt "$HOME/.certs/corporate.pem")
          $DRY_RUN_CMD sh -c 'printf "%s" "$1" > "$2"' -- "$_bundle" \
            "$HOME/.certs/combined-ca-bundle.crt"
        else
          echo "WARNING: ~/.certs/corporate.pem not found — see docs/bootstrap.md"
        fi
      '');

    # Work SSH stubs — included via the `Include ~/.ssh/config.d/*` in base.nix programs.ssh
    file.".ssh/config.d/work".text = ''
      # Work VPN / jump host — fill in hostnames before use
      # Host work-jump
      #   HostName jump.corp.example.com
      #   User ${user.username}
      #   IdentityFile ~/.ssh/${user.sshKey}
    '';
  };

  # Git identity for work — overrides the personal identity set in base.nix
  programs.git = {
    userName = lib.mkForce user.work.name;
    userEmail = lib.mkForce user.work.email;
  };
}
