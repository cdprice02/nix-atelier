# List available commands
default:
    @just --list

# Apply home-manager profile (Linux/WSL2) — PROFILE=work or PROFILE=personal
switch PROFILE="personal":
    home-manager switch --flake ~/.nix-config#{{PROFILE}} --impure

# Apply nix-darwin config (macOS) — PROFILE=personal-darwin or PROFILE=work-darwin
rebuild PROFILE="personal-darwin":
    sudo darwin-rebuild switch --flake ~/.nix-config#{{PROFILE}} --impure

# Update all flake inputs
update:
    nix flake update --flake ~/.nix-config

# Validate flake without applying
check:
    nix flake check --impure

# Update submodules to latest commit on their tracked branch
sync:
    git submodule update --remote --merge
