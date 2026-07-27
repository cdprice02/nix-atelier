# List available commands
default:
    @just --list

# Apply home-manager profile (Linux/WSL2) — PROFILE=work or PROFILE=personal
# -b bk backs up any conflicting file (e.g. a real ~/.claude dir) instead of
# hard-failing, matching nix-darwin's backupFileExtension = "bk" behavior.
switch PROFILE="personal":
    home-manager switch --flake {{justfile_directory()}}#{{PROFILE}} --impure -b bk

# Apply nix-darwin config (macOS) — PROFILE=personal-darwin or PROFILE=work-darwin
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

# Enter a nightly Rust shell (rust-overlay's stable toolchain stays the
# profile default — see docs/tools.md for why rustup is not installed
# alongside it). Exits back to the stable toolchain on shell exit.
rust-nightly:
    nix develop {{justfile_directory()}}#rust-nightly

# Format all Nix files with alejandra
fmt:
    nix fmt {{justfile_directory()}}
