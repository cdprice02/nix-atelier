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

# Apply this machine's configuration. Dispatches by OS: nix-darwin on macOS,
# standalone home-manager on Linux/WSL2. `just switch work`, or `just switch`
# for the default. On macOS the arch-specific darwin suffix is appended when
# absent — `-darwin-aarch64` on Apple Silicon, `-darwin` on Intel — so the same
# `personal`/`work` names select the right config on either Mac.
switch PROFILE=default_profile:
    #!/usr/bin/env bash
    set -euo pipefail
    profile="{{PROFILE}}"
    if [ "$(uname)" = "Darwin" ]; then
        case "$profile" in
            *-darwin | *-darwin-aarch64) ;; # already an explicit darwin config
            *)
                if [ "$(uname -m)" = "arm64" ]; then
                    profile="${profile}-darwin-aarch64"
                else
                    profile="${profile}-darwin"
                fi
                ;;
        esac
        sudo darwin-rebuild switch --flake {{justfile_directory()}}#"$profile" --impure
    else
        home-manager switch --flake {{justfile_directory()}}#"$profile" --impure -b bk
    fi

# Backwards-compatible alias — `just rebuild` still applies the darwin config.
alias rebuild := switch

# Safe to run on any machine: this does NOT advance any release pin. The darwin
# pin lives in flake.nix's input refs (nixpkgs-25.05-darwin / release-25.05),
# not in flake.lock, so re-resolving can only ever land on another 25.05 commit
# — moving that pin means editing flake.nix by hand. Only the rolling
# Linux/WSL2 inputs (nixpkgs-unstable / home-manager master) actually advance.
#
# Takes no input argument by design: nixpkgs and home-manager are a
# release-matched pair (as are their darwin counterparts), and updating one
# alone desyncs it from its partner, which flake.nix then hard-fails on.
# Re-resolving everything at once keeps both pairs consistent by construction.
#
# Re-resolve all flake inputs against the refs declared in flake.nix
update:
    nix flake update --flake {{justfile_directory()}}
    @echo "Inputs updated — run 'just check' before 'just switch'."

# Validate flake without applying. Checks THIS system only: the `checks`
# output builds Linux activation packages, so `--all-systems` on a Mac would
# try to build `checks.x86_64-linux.*` and fail for lack of a Linux builder.
# CI runs the full cross-system matrix (see .github/workflows/check.yml).
check:
    nix flake check --impure

# Update submodules to latest commit on their tracked branch
sync:
    git -C {{justfile_directory()}} submodule update --remote --merge

# Enter a nightly Rust shell for feature-gated code (stable stays the profile default)
rust-nightly:
    nix develop {{justfile_directory()}}#rust-nightly

# Format all Nix files with alejandra
fmt:
    nix fmt {{justfile_directory()}}

# Regenerate docs/profiles.md and docs/tools.md from Nix (modules/docs-gen.nix)
# and overwrite the committed files. Run after changing modules/profile-list.nix,
# modules/tool-catalog.nix, modules/features.nix, or modules/profiles.nix —
# CI's docs-drift check fails if the committed files disagree with this output.
docs:
    #!/usr/bin/env bash
    set -euo pipefail
    dir="{{justfile_directory()}}"
    system="$(nix eval --impure --raw --expr 'builtins.currentSystem')"
    cp "$(nix build "$dir"#packages."$system".docs-profiles-md --impure --no-link --print-out-paths)" "$dir/docs/profiles.md"
    cp "$(nix build "$dir"#packages."$system".docs-tools-md --impure --no-link --print-out-paths)" "$dir/docs/tools.md"
    chmod +w "$dir/docs/profiles.md" "$dir/docs/tools.md"
    echo "docs/profiles.md and docs/tools.md regenerated."

