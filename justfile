# Default profile: read from user.nix's `profile` field if set, else
# "personal". Backtick assignment runs once when just parses this file.
# `grep .` makes the fallback fire on empty output: the trailing `|| echo`
# guards only the last pipeline stage, so without it a failed `nix eval` (no
# user.nix, or nix not yet on PATH) would leave `tr` exiting 0 and the default
# empty. grep exits non-zero on no input, triggering the fallback.
default_profile := `nix eval --impure --expr '(import ./user.nix).profile or "personal"' 2>/dev/null | tr -d '"' | grep . || echo personal`

# Recipes prefixed with `_` are CI-internal plumbing, hidden from `just
# --list` by design (just's own private-recipe convention) but still
# runnable (`just _build-linux personal`) and inspectable (`just --show
# _build-linux`) — not a black box, just not cluttering the everyday list.
#
# Relative paths below are bare (`.`, `docs/...`) rather than
# `{{ justfile_directory() }}`-prefixed: just runs every recipe with cwd set
# to the justfile's own directory by default, regardless of where `just` was
# invoked from (verified directly, not assumed).

default:
    @just --list

[group('machine')]
[doc('Apply configuration for this machine (dispatches by OS)')]
switch PROFILE=default_profile:
    #!/usr/bin/env bash
    set -euo pipefail
    profile="{{ PROFILE }}"
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
        sudo darwin-rebuild switch --flake .#"$profile" --impure
    else
        home-manager switch --flake .#"$profile" --impure -b bk
    fi

# Backwards-compatible alias — `just rebuild` still applies the darwin config.
alias rebuild := switch

# Safe to run on any machine: this does NOT advance any release pin. The darwin
# pin lives in flake.nix's input refs (nixpkgs-25.05-darwin / release-25.05),
# not in flake.lock, so re-resolving can only ever land on another 25.05 commit
# — moving that pin means editing flake.nix by hand. Only the rolling
# Linux/WSL2 inputs (nixpkgs-unstable / home-manager master) actually advance.
[group('machine')]
[doc('Re-resolve all flake inputs together — never a single input')]
update:
    nix flake update
    @echo "Inputs updated — run 'just check' before 'just switch'."

[group('machine')]
[doc('Update submodules to latest commit on their tracked branch')]
sync:
    git submodule update --remote --merge

# Validate flake without applying. Checks THIS system only: the `checks`
# output builds Linux activation packages, so `--all-systems` on a Mac would
# try to build `checks.x86_64-linux.*` and fail for lack of a Linux builder.
# CI runs the full cross-system matrix (see .github/workflows/check.yml).
[group('check')]
[doc('Full local validation (builds profiles for this system + lints)')]
check:
    nix flake check --impure

[group('check')]
[doc('Fast: eval every profile without building')]
eval-all:
    #!/usr/bin/env bash
    set -euo pipefail
    mapfile -t linux < <({{ just_executable() }} _list-linux-profiles | jq -r '.[]')
    for p in "${linux[@]}"; do
        echo "eval homeConfigurations.$p"
        nix eval --impure --raw .#homeConfigurations."$p".activationPackage.drvPath >/dev/null
    done
    mapfile -t darwin < <({{ just_executable() }} _list-darwin-profiles | jq -r '.[]')
    for p in "${darwin[@]}"; do
        echo "eval darwinConfigurations.$p"
        nix eval --impure --raw .#darwinConfigurations."$p".config.system.build.toplevel.drvPath >/dev/null
    done
    echo "All 20 profiles evaluated cleanly."

[group('check')]
[doc('Run all lints (alejandra, statix, deadnix, markdownlint)')]
lint-all: _lint-alejandra _lint-statix _lint-deadnix _lint-markdownlint

[group('generate')]
[doc('Format all Nix files with alejandra')]
fmt:
    nix fmt

# Regenerated content only — see modules/docs-gen.nix for what's generated
# vs. hand-maintained within the two files.
[group('generate')]
[doc('Regenerate docs/profiles.md + docs/tools.md from Nix')]
docs:
    #!/usr/bin/env bash
    set -euo pipefail
    system="$(nix eval --impure --raw --expr 'builtins.currentSystem')"
    cp "$(nix build .#packages."$system".docs-profiles-md --impure --no-link --print-out-paths)" docs/profiles.md
    cp "$(nix build .#packages."$system".docs-tools-md --impure --no-link --print-out-paths)" docs/tools.md
    chmod +w docs/profiles.md docs/tools.md
    echo "docs/profiles.md and docs/tools.md regenerated."

[private]
_list-linux-profiles:
    @nix eval --impure --json .#homeConfigurations --apply builtins.attrNames

[private]
_list-darwin-profiles:
    @nix eval --impure --json .#darwinConfigurations --apply builtins.attrNames

[private]
_build-linux PROFILE:
    nix build .#homeConfigurations.{{ PROFILE }}.activationPackage --impure

[private]
_build-darwin PROFILE:
    nix build .#darwinConfigurations.{{ PROFILE }}.system --impure

[private]
_lint-alejandra:
    nix shell nixpkgs#alejandra -c alejandra --check .

[private]
_lint-statix:
    nix shell nixpkgs#statix -c statix check

[private]
_lint-deadnix:
    nix shell nixpkgs#deadnix -c deadnix --fail .

[private]
_lint-markdownlint:
    nix shell nixpkgs#markdownlint-cli -c markdownlint 'docs/**/*.md' README.md CONTRIBUTING.md CLAUDE.md
