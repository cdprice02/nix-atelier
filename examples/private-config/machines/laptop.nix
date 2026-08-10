# Adds a machine-specific environment variable and PATH entry -- a locally
# installed tool outside Nix, a laptop-only working-directory convention,
# anything the public framework has no business knowing about because it
# only makes sense on this one machine.
{config, ...}: {
  home.sessionVariables = {
    MY_LAPTOP_ONLY_VAR = "some-machine-specific-value";
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/bin" # e.g. scripts synced here by some other tool
  ];
}
