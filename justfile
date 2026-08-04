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
# _build-linux`), not a black box, just not cluttering the everyday list.
#
# Relative paths below are bare (`.`, `docs/...`) rather than
# `{{ justfile_directory() }}`-prefixed: just runs every recipe with cwd set
# to the justfile's own directory by default, regardless of where `just` was
# invoked from (verified directly, not assumed).

default:
    @just --list

# Resolves a bare profile name (e.g. "personal") to the config for THIS
# machine's OS and CPU, so nobody has to know the naming scheme to apply their
# own config. An explicit name is still honoured -- it is just checked against
# the machine first, and warned about rather than silently built for the wrong
# platform, which is what a mismatched name used to do.
[group('machine')]
[doc('Apply configuration for this machine (auto-detects OS and CPU)')]
switch PROFILE=default_profile:
    #!/usr/bin/env bash
    set -euo pipefail
    profile="{{ PROFILE }}"

    # uname -m reports arm64 on macOS and aarch64 on Linux for the same CPU.
    case "$(uname -m)" in
        arm64 | aarch64) arch=aarch64 ;;
        x86_64 | amd64)  arch=x86_64 ;;
        *) echo "error: unrecognised CPU '$(uname -m)'." >&2
           echo "  Pass an explicit profile name: just switch <profile>" >&2
           exit 1 ;;
    esac

    if [ "$(uname)" = "Darwin" ]; then
        # darwinConfigurations: <context>-darwin on Intel,
        # <context>-darwin-aarch64 on Apple Silicon.
        case "$profile" in
            *-darwin-aarch64)
                [ "$arch" = aarch64 ] \
                    || echo "WARNING: $profile is the Apple Silicon config, but this Mac is Intel." >&2 ;;
            *-darwin)
                [ "$arch" = x86_64 ] \
                    || echo "WARNING: $profile is the Intel config, but this Mac is Apple Silicon (did you mean ${profile}-aarch64?)." >&2 ;;
            # A Linux-style name. Appending a darwin suffix would produce
            # nonsense like personal-aarch64-darwin-aarch64, so refuse.
            *-aarch64)
                echo "error: '$profile' is a Linux config name; this is macOS." >&2
                echo "  Use '${profile%-aarch64}-darwin-aarch64' (Apple Silicon) or '${profile%-aarch64}-darwin' (Intel)." >&2
                exit 1 ;;
            *)
                if [ "$arch" = aarch64 ]; then
                    profile="${profile}-darwin-aarch64"
                else
                    profile="${profile}-darwin"
                fi ;;
        esac
        sudo darwin-rebuild switch --flake .#"$profile" --impure
    else
        # homeConfigurations: <profile> is x86_64-linux, <profile>-aarch64 is
        # aarch64-linux. This half previously did no arch handling at all, so
        # on an ARM machine `just switch personal` resolved to the *x86_64*
        # config and built for the wrong architecture.
        case "$profile" in
            *-darwin | *-darwin-aarch64)
                echo "error: '$profile' is a macOS config; this is $(uname)." >&2
                echo "  Use '${profile%-darwin*}' (x86_64) or '${profile%-darwin*}-aarch64' (aarch64)." >&2
                exit 1 ;;
            *-aarch64)
                [ "$arch" = aarch64 ] \
                    || echo "WARNING: $profile is the aarch64 config, but this machine is x86_64." >&2 ;;
            *)
                if [ "$arch" = aarch64 ]; then
                    profile="${profile}-aarch64"
                fi ;;
        esac
        home-manager switch --flake .#"$profile" --impure -b bk
    fi

# `just rebuild` is a pure alias for `switch`, kept only so muscle memory from
# the pre-`just` `darwin-rebuild` era still works. It is NOT the macOS
# counterpart to a Linux-only `switch`: `switch` dispatches by OS on its own
# (see the uname branch above), so the two are the same recipe on every
# platform. docs/troubleshooting.md used to present them as an OS split, which
# was misleading; it now documents `switch` alone.
alias rebuild := switch

# Safe to run on any machine: this does NOT advance any release pin. The darwin
# pin lives in flake.nix's input refs (nixpkgs-25.05-darwin / release-25.05),
# not in flake.lock, so re-resolving can only ever land on another 25.05 commit;
# moving that pin means editing flake.nix by hand. Only the rolling
# Linux/WSL2 inputs (nixpkgs-unstable / home-manager master) actually advance.
[group('machine')]
[doc('Re-resolve all flake inputs together, never a single input')]
update:
    nix flake update
    @echo "Inputs updated, run 'just check' before 'just switch'."

[group('machine')]
[doc('Update submodules to latest commit on their tracked branch')]
sync:
    git submodule update --remote --merge

# Propagate shared Claude config from the public repo into the private work
# overlay. Profiles are separated by branch and remote: public `main` holds
# everything shareable, the private `work` branch adds employer-specific config
# that must never reach a public repo. Without a cadence the work branch rots;
# it has already drifted once.
#
# Run this on a work machine, where config/claude is checked out on `work`.
[group('machine')]
[doc('Merge shared changes from public main into the private work branch')]
sync-work:
    #!/usr/bin/env bash
    set -euo pipefail
    cd config/claude
    branch=$(git rev-parse --abbrev-ref HEAD)
    if [ "$branch" != "work" ]; then
        echo "config/claude is on '$branch', not 'work'; nothing to do." >&2
        echo "This recipe is for work machines. See user.nix submodules." >&2
        exit 1
    fi
    git fetch origin
    behind=$(git rev-list --count HEAD..origin/main)
    if [ "$behind" -eq 0 ]; then
        echo "work is already up to date with origin/main."
        exit 0
    fi
    echo "Merging $behind commit(s) from origin/main into work…"
    git merge origin/main
    echo "Merged. Review, then: git push private work:main"

# Validate flake without applying. Checks THIS system only: the `checks`
# output builds Linux activation packages, so `--all-systems` on a Mac would
# try to build `checks.x86_64-linux.*` and fail for lack of a Linux builder.
# CI runs the full cross-system matrix (see .github/workflows/check.yml).
#
# Runs lint-all explicitly because the lints deliberately live outside the
# flake's `checks` output (see flake.nix's comment there: they were being run
# twice per PR). Keeping them here means a green `just check` still covers
# formatting and lint, and covers the working tree rather than the last commit.
[group('check')]
[doc('Full local validation (builds profiles for this system + lints)')]
check: lint-all
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
    total=$(( ${#linux[@]} + ${#darwin[@]} ))
    echo "All $total profiles evaluated cleanly."

[group('check')]
[doc('Run all lints (alejandra, statix, deadnix, markdownlint)')]
lint-all: _lint-alejandra _lint-statix _lint-deadnix _lint-markdownlint

# Wraps the run in `nix develop` because .pre-commit-config.yaml's alejandra
# and markdownlint hooks use `language: system`; they resolve to whatever is
# on PATH, which is only correct inside the devShell. Running `pre-commit run`
# bare either picks up a different version of those tools or fails to find
# them, and the docs told users to do exactly that (CONTRIBUTING.md,
# docs/bootstrap.md steps 9 and 8) without mentioning the devShell.
[group('check')]
[doc('Run every pre-commit hook over all files, inside the devShell')]
precommit:
    nix develop -c pre-commit run --all-files

# Thin wrapper over `nix fmt` on purpose: it exists so formatting is
# discoverable from `just --list` alongside every other everyday command,
# rather than being the one task you have to already know a different entry
# point for. `nix fmt` resolves to the `formatter` output (alejandra).
[group('generate')]
[doc('Format all Nix files with alejandra')]
fmt:
    nix fmt

# Regenerated content only; see modules/docs-gen.nix for what's generated
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

# Lints exactly the Markdown this repo tracks, derived from git rather than a
# hand-listed set of paths (which previously lived here, in flake.nix and in
# .pre-commit-config.yaml in three different syntaxes, and had already drifted:
# CODE_OF_CONDUCT.md and .github/pull_request_template.md were in none of
# them). `git ls-files` also naturally excludes untracked local scratch files,
# which a bare '**/*.md' glob would pick up. Submodule content under config/ is
# excluded via .markdownlintignore.
[private]
_lint-markdownlint:
    git ls-files -z '*.md' | xargs -0 nix shell nixpkgs#markdownlint-cli -c markdownlint
