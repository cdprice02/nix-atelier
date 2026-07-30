# Default profile: read from user.nix's `profile` field if set, else
# "personal". Backtick assignment runs once when just parses this file.
# `grep .` makes the fallback fire on empty output: the trailing `|| echo`
# guards only the last pipeline stage, so without it a failed `nix eval` (no
# user.nix, or nix not yet on PATH) would leave `tr` exiting 0 and the default
# empty. grep exits non-zero on no input, triggering the fallback.
default_profile := `nix eval --impure --expr '(import ./user.nix).profile or "personal"' 2>/dev/null | tr -d '"' | grep . || echo personal`

# List available commands
default:
    @just --list

# Apply home-manager profile (Linux/WSL2): `just switch work`, or `just switch` for the default
switch PROFILE=default_profile:
    home-manager switch --flake {{justfile_directory()}}#{{PROFILE}} --impure -b bk

# Apply nix-darwin config (macOS): `just rebuild work-darwin`, or `just rebuild` for the default
rebuild PROFILE="personal-darwin":
    sudo darwin-rebuild switch --flake {{justfile_directory()}}#{{PROFILE}} --impure

# Update all flake inputs
update:
    nix flake update --flake {{justfile_directory()}}

# Validate flake without applying
check:
    nix flake check --impure --all-systems

# Update submodules to latest commit on their tracked branch
sync:
    git -C {{justfile_directory()}} submodule update --remote --merge

# Enter a nightly Rust shell for feature-gated code (stable stays the profile default)
rust-nightly:
    nix develop {{justfile_directory()}}#rust-nightly

# Format all Nix files with alejandra
fmt:
    nix fmt {{justfile_directory()}}

