# Fixture for the feature-platform-filtering check in flake.nix's `checks`:
# a module that does nothing, used only as a comparable value (a Nix path,
# not a lambda -- paths support ==, functions don't) to confirm mkProfile
# actually drops a feature declared unsupported on a given system rather
# than keeping it.
_: { }
