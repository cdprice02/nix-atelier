# Default profile: read from user.nix's `profile` field if set, else "full".
# Backtick assignment runs once when just parses this file. `grep .` makes
# the fallback fire on empty output: the trailing `|| echo` guards only the
# last pipeline stage, so without it a failed `nix eval` (no user.nix, or nix
# not yet on PATH) would leave `tr` exiting 0 and the default empty. grep
# exits non-zero on no input, triggering the fallback.
default_profile := `nix eval --impure --expr '(import ./user.nix).profile or "full"' 2>/dev/null | tr -d '"' | grep . || echo full`

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

# Resolves a bare profile name (e.g. "full") to the config for THIS
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
        # darwinConfigurations: <name>-darwin on Intel,
        # <name>-darwin-aarch64 on Apple Silicon.
        case "$profile" in
            *-darwin-aarch64)
                [ "$arch" = aarch64 ] \
                    || echo "WARNING: $profile is the Apple Silicon config, but this Mac is Intel." >&2 ;;
            *-darwin)
                [ "$arch" = x86_64 ] \
                    || echo "WARNING: $profile is the Intel config, but this Mac is Apple Silicon (did you mean ${profile}-aarch64?)." >&2 ;;
            # A Linux-style name. Appending a darwin suffix would produce
            # nonsense like full-aarch64-darwin-aarch64, so refuse.
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
        # on an ARM machine `just switch full` resolved to the *x86_64*
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

# Validate flake without applying. Checks THIS system only by default: the
# `checks` output still does a handful of *real* small builds (fzf/zoxide/
# direnv, captured statically by nmt's shell-init tests), so `--all-systems`
# on a Mac would try to build `checks.x86_64-linux.*`'s real packages and fail
# for lack of a Linux builder. CI's flake-check job passes its own system
# explicitly per matrix entry instead (see .github/workflows/check.yml),
# using QEMU/Rosetta the same way build-linux/build-darwin do.
#
# This is now the whole local validation story, formatting included: `checks`
# carries `formatting` (treefmt: nixfmt-rfc-style + statix + deadnix +
# mdformat, see treefmt.nix), so a green `just check` already covers it --
# there's no separate `lint-all` recipe anymore (there used to be, back when
# lints lived outside `checks` specifically to avoid running four separate
# tools twice per PR; treefmt collapsed that into one tool, so the reason for
# keeping them apart went away with it).
[group('check')]
[doc('Full local validation (builds profiles for this system)')]
check: flake-check

# `system` defaults to whatever's actually running this, so local use
# (`just flake-check`, no args) is unchanged; CI's matrix passes each entry's
# target system explicitly.
[group('check')]
[doc("nix flake check only; CI's flake-check job uses this per system")]
flake-check system=`nix eval --impure --raw --expr 'builtins.currentSystem'`:
    nix flake check --impure --system {{ system }}

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

# Wraps the run in `nix develop` because .pre-commit-config.yaml's treefmt
# hook uses `language: system`; it resolves to whatever is on PATH, which is
# only correct inside the devShell. Running `pre-commit run` bare either picks
# up a different version of the tool or fails to find it, and the docs told
# users to do exactly that (CONTRIBUTING.md, docs/bootstrap.md steps 9 and 8)
# without mentioning the devShell.
[group('check')]
[doc('Run every pre-commit hook over all files, inside the devShell')]
precommit:
    nix develop -c pre-commit run --all-files

# Thin wrapper over `nix fmt` on purpose: it exists so formatting is
# discoverable from `just --list` alongside every other everyday command,
# rather than being the one task you have to already know a different entry
# point for. `nix fmt` resolves to the `formatter` output (treefmt: nixfmt-
# rfc-style + statix + deadnix + mdformat, see treefmt.nix) -- auto-fixes,
# not just reformats: statix/deadnix apply real fixes, not only whitespace.
[group('generate')]
[doc('Format everything (nixfmt-rfc-style, statix, deadnix, mdformat)')]
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

# Splits _list-linux-profiles by arch suffix rather than deriving a second
# source of truth: CI's build-linux-x86_64/build-linux-aarch64 jobs need
# separate matrices (x86_64 on every PR, aarch64 push-gated only -- see
# check.yml), and this is the one place that split has to happen.
[private]
_list-linux-profiles-x86_64:
    @{{ just_executable() }} _list-linux-profiles | jq -c '[.[] | select(endswith("-aarch64") | not)]'

[private]
_list-linux-profiles-aarch64:
    @{{ just_executable() }} _list-linux-profiles | jq -c '[.[] | select(endswith("-aarch64"))]'

[private]
_list-darwin-profiles:
    @nix eval --impure --json .#darwinConfigurations --apply builtins.attrNames

[private]
_build-linux PROFILE:
    nix build .#homeConfigurations.{{ PROFILE }}.activationPackage --impure

[private]
_build-darwin PROFILE:
    nix build .#darwinConfigurations.{{ PROFILE }}.system --impure
