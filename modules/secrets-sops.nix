# Opt-in only: see mkProfile's sopsMods in flake.nix for why this module
# isn't imported by default. Enable per-machine via user.nix: useSops = true;
#
# The age private key at sops.age.keyFile below is NOT provisioned by this
# module: deliberately manual, not an activation-script fetch from any
# particular password manager. Two reasons:
#   1. Chicken-and-egg: sops/age/rbw only land on PATH after a completed
#      `home-manager switch`, so an activation hook can't lean on them
#      during the very first switch on a new machine anyway.
#   2. Portability: this repo is public and meant to be forkable (see
#      CONTRIBUTING.md). Hard-wiring one password manager's CLI into the
#      only path to a working age key would make sops usage needlessly
#      dependent on it for anyone else adopting this pattern.
# Place the key yourself before enabling useSops (see docs/bootstrap.md):
#   mkdir -p ~/.config/sops/age && chmod 700 ~/.config/sops/age
#   <write your age private key to ~/.config/sops/age/keys.txt>
#   chmod 600 ~/.config/sops/age/keys.txt
{config, ...}: {
  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    defaultSopsFile = ../secrets/secrets.yaml;

    secrets = {
      GITHUB_PERSONAL_ACCESS_TOKEN = {};
      GITLAB_ACCESS_TOKEN = {};
      GITLAB_VERIFY_SSL = {};
      JIRA_PAT = {};
      CONTEXT7_API_KEY = {};
    };

    # Renders straight to the same path envLocalInit (base.nix) already
    # sources on every shell: nothing downstream needs to change to pick
    # this up once useSops is on.
    templates."secrets-env" = {
      path = "${config.home.homeDirectory}/.config/secrets/env";
      mode = "0400";
      content = ''
        export GITHUB_PERSONAL_ACCESS_TOKEN="${config.sops.placeholder.GITHUB_PERSONAL_ACCESS_TOKEN}"
        export GITLAB_ACCESS_TOKEN="${config.sops.placeholder.GITLAB_ACCESS_TOKEN}"
        export GITLAB_VERIFY_SSL="${config.sops.placeholder.GITLAB_VERIFY_SSL}"
        export JIRA_PAT="${config.sops.placeholder.JIRA_PAT}"
        export CONTEXT7_API_KEY="${config.sops.placeholder.CONTEXT7_API_KEY}"
      '';
    };
  };
}
