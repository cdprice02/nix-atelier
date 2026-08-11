{
  pkgs,
  lib,
  user,
  ...
}:
{
  home = {
    packages = with pkgs; [
      awscli2
      aws-vault
      s5cmd
      ssm-session-manager-plugin
    ];

    sessionVariables = {
      # aws-vault's backend has no cross-platform default: this nixpkgs
      # build only supports [keychain pass file] (no secret-service/kwallet),
      # and "keychain": its compiled-in default: only exists on macOS, so
      # aws-vault errors at runtime on Linux unless a backend is set
      # explicitly. "file" needs no daemon/keyring, so it works identically
      # on a GUI dev machine and a headless minimal-tier machine alike.
    }
    // lib.optionalAttrs (!pkgs.stdenv.isDarwin) {
      AWS_VAULT_BACKEND = "file";
    }
    // lib.optionalAttrs (user.aws.profile or null != null) {
      # Left unset by default: a hardcoded default here risks accidentally
      # running a command against the wrong AWS account. Set
      # user.aws.profile in user.nix to opt in on a given machine.
      AWS_PROFILE = user.aws.profile;
    };

    # Skeleton only: written once, never overwritten. Real profiles get
    # added over time via `aws configure`/`aws configure sso`/`aws-vault add`,
    # so this must survive future `home-manager switch` runs undisturbed
    # (unlike a home.file entry, which would reset it to the skeleton on
    # every switch and silently discard those additions).
    # $DRY_RUN_CMD can't prefix the heredoc/cat below: prefixing only affects
    # what command runs, not the `>` redirection, which the shell applies
    # regardless: under a dry run that would still truncate the real file
    # with the literal word "cat", the opposite of a no-op. Skipping the
    # write entirely when $DRY_RUN_CMD is set avoids that.
    activation.awsConfigSkeleton = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -f "$HOME/.aws/config" ]; then
        if [ -n "''${DRY_RUN_CMD:-}" ]; then
          echo "Would create $HOME/.aws/config"
        else
          mkdir -p "$HOME/.aws"
          cat > "$HOME/.aws/config" <<'EOF'
      [default]
      # region = us-east-1
      # output = json

      # Named profiles: add one per AWS account/role, e.g.:
      # [profile myprofile]
      # region = us-west-2
      # output = json
      # sso_session = my-sso
      EOF
          echo "~/.aws/config created: edit to add named profiles."
        fi
      fi
    '';
  };
}
