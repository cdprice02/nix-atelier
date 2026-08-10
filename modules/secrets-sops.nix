# Opt-in only: see mkProfile's sopsMods in flake.nix for why this module
# isn't imported by default. Enable per-machine by setting user.nix's
# sopsFile -- its presence is the trigger, no separate boolean.
#
# Generates sops.secrets and the ~/.config/secrets/env template purely from
# user.nix's own `secrets` (a list of names) and `sopsFile` (an absolute
# path). The framework has no opinion on what secrets anyone needs: adding
# one is a user.nix edit, never a change here. sopsFile is deliberately a
# per-machine setting, not a single canonical path: if a service's token
# genuinely differs per machine (personal laptop vs. a work machine), point
# each machine's user.nix at its own secrets.yaml with its own values under
# the same key names, rather than sharing one file across machines.
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
# Place the key yourself before setting sopsFile (see docs/bootstrap.md):
#   mkdir -p ~/.config/sops/age && chmod 700 ~/.config/sops/age
#   <write your age private key to ~/.config/sops/age/keys.txt>
#   chmod 600 ~/.config/sops/age/keys.txt
{
  config,
  lib,
  user,
  ...
}: let
  secretNames = user.secrets or [];
in {
  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

    # sops-nix's default (true) means "this sopsFile must live in the Nix
    # store", checked by a build-time (sandboxed) check phase that literally
    # opens the file -- fundamentally incompatible with sopsFile pointing at
    # a real, private, out-of-repo path, which is the entire point of this
    # module. Verified directly: a real `nix build` failed with EACCES
    # opening the file from inside the sandbox before this was set. sops-nix
    # itself documents this exact escape hatch for exactly this case;
    # decryption still only ever happens at activation time regardless.
    validateSopsFiles = false;

    # No fallback to this repo's own secrets/secrets.yaml.example: it's
    # encrypted for nobody (a placeholder recipient, see .sops.yaml), so a
    # missing sopsFile has to fail loudly here rather than resolve to a file
    # sops can never actually decrypt. Unreachable in the normal path --
    # flake.nix only imports this module once sopsFile is already set -- but
    # cheap insurance against this module being reached some other way.
    defaultSopsFile =
      user.sopsFile or (throw ''
        secrets-sops.nix requires user.nix's sopsFile to point at your own
        secrets.yaml (typically in a private config repo alongside any
        extraModulePaths modules) -- see docs/bootstrap.md.
      '');

    secrets = lib.genAttrs secretNames (_: {});

    # Renders straight to the same path envLocalInit (base.nix) already
    # sources on every shell: nothing downstream needs to change to pick
    # this up once sopsFile is set.
    templates."secrets-env" = {
      path = "${config.home.homeDirectory}/.config/secrets/env";
      mode = "0400";
      content =
        lib.concatMapStrings
        (name: ''
          export ${name}="${config.sops.placeholder.${name}}"
        '')
        secretNames;
    };
  };
}
