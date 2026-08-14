# Troubleshooting

Common first-boot failures and how to fix them.

______________________________________________________________________

## home-manager / nixpkgs release mismatch

**Symptom (before the guard existed):** the switch *succeeds*, but prints a
warning block plus unrelated-looking deprecation noise:

```text
trace: warning: You are using
  Home Manager version 25.11 and
  Nixpkgs version 26.11.
evaluation warning: fold has been deprecated, use foldr instead
evaluation warning: The xorg package set has been deprecated, ...
There are 289 unread and relevant news items.
```

**Symptom (with the guard):** evaluation fails outright with

```text
error: Linux/WSL2 (rolling): home-manager (25.11) and nixpkgs (26.11) releases disagree.
```

**Cause:** one input of a release pair was updated without the other: e.g.
`nixpkgs` bumped to a new unstable revision while `home-manager` stayed behind.
The deprecation warnings are old HM module code calling nixpkgs APIs that the
newer nixpkgs deprecated; the news backlog is the changelog for the months of
HM history that got skipped.

**Fix:** update both inputs of the pair together.

```sh
just update      # re-resolves all inputs; never update a single input
just check       # confirm all profiles still build
just switch
```

This does not disturb the x86_64-darwin pin: `just update` re-resolves each
input against the ref declared in `flake.nix`, and the pinned darwin refs are
release branches (`nixpkgs-25.05-darwin` / `release-25.05` / `nix-darwin-25.05`),
so they can only land on another 25.05 commit. Only the rolling inputs
(Linux/WSL2 + aarch64-darwin) advance.

`just update` deliberately accepts no input name: see the pairing invariant in
`CLAUDE.md`. If you must update by hand, move a whole release group together
(each nix-darwin / home-manager is coupled to its nixpkgs release; nix-darwin
hard-fails eval on a mismatch, and `checkReleasePair` guards the home-manager
side):

```sh
# Rolling group: Linux/WSL2 + aarch64-darwin
nix flake update nixpkgs home-manager nix-darwin
# Pinned group: x86_64-darwin
nix flake update nixpkgs-darwin home-manager-darwin nix-darwin-x86
```

______________________________________________________________________

## A newly installed tool stays shadowed, or a `sessionPath` entry is missing from `PATH`

**Symptom:** After a `switch` that adds a new entry to `home.sessionPath`
(e.g. `modules/env.nix`'s `~/.local/bin`), the new directory is missing from
`PATH` in *every* shell, including brand-new ones, while older entries are
still present. A freshly installed tool stays shadowed by an older copy
elsewhere: `command -v claude` resolves to `~/.npm-global/bin/claude` instead
of the newer `~/.local/bin/claude`, and the claude-code installer even reports
it directly:

```text
⚠ Native installation exists but ~/.local/bin is not in your PATH.
```

Opening a new terminal window does **not** fix it, which is the confusing
part.

**Cause:** not a bug in this config. Home Manager's generated
`hm-session-vars.sh` guards itself against being sourced twice per shell:

```sh
if [ -n "$__HM_SESS_VARS_SOURCED" ]; then return; fi
export __HM_SESS_VARS_SOURCED=1
```

That guard variable is **exported**, so every child process inherits it. Once
one shell has sourced an *older* version of the file, every shell descended
from it (including `zsh -l`, tmux panes, and editor terminals) sees the
guard already set and returns before applying the new `PATH`. The stale value
propagates indefinitely, which is why even a new terminal window doesn't help
if it was itself spawned from (or inherits the environment of) an
already-affected session.

**Diagnose:** compare `PATH` with and without the guard:

```sh
# stale/current PATH, whatever this shell inherited
echo $PATH

# what PATH would be if hm-session-vars.sh were sourced fresh
env -u __HM_SESS_VARS_SOURCED zsh -l -c 'echo $PATH'
```

If the two differ, the guard is the cause.

**Fix:**

```sh
# fix the current session in place
exec env -u __HM_SESS_VARS_SOURCED zsh -l
```

A genuinely new *login* session, such as a new terminal app launch or logging
out and back in, also clears it, since neither inherits environment from the
affected shell. Spawning a shell from within the affected session does not.

See `modules/env.nix`'s comment block for the related (and separate)
Linux-vs-darwin `PATH`-ordering behavior, which is often what you're checking
when this surfaces.

______________________________________________________________________

## Submodule directories empty after clone

**Symptom:** `~/.nix-atelier/config/claude/` is empty, or Home Manager errors on the symlink activation step.

**Cause:** The repo was cloned without `--recurse-submodules`.

**Fix:**

```sh
git -C ~/.nix-atelier submodule update --init --recursive
```

Or clone correctly from the start:

```sh
git clone --recurse-submodules https://github.com/cdprice02/nix-atelier.git ~/.nix-atelier
```

______________________________________________________________________

## SSH key not added to GitHub → submodule fetch fails

**Symptom:** During `home-manager switch`, the activation script prints:

```text
WARNING: submodule claude: fetch from private remote failed.
  Ensure your SSH key is added to GitHub, then rerun: home-manager switch --flake ~/.nix-atelier
```

**Fix:**

```sh
# Print your public key
cat ~/.ssh/<sshKey>.pub

# Paste it at: https://github.com/settings/keys
# Then re-run:
home-manager switch --flake ~/.nix-atelier#<profile>
```

`<sshKey>` is the prefix of your identity's email (the `email` field in your
`flake.nix`'s `lib.mkConfigs` call, e.g. `you` for `you@example.com`).

______________________________________________________________________

## Home Manager symlink conflict (`~/.claude` already exists)

**Symptom:** Home Manager warns about a backup file or fails to create `~/.claude`.

**Cause:** `~/.claude` exists as a real directory (e.g. from a previous manual install) rather than a symlink. `just switch`/`just rebuild` pass `backupFileExtension = "bk"` (Linux via `-b bk`, darwin via the persistent module option), so it will rename the existing path to `~/.claude.bk` instead of failing outright. A bare `home-manager switch` invocation without `-b bk` does not get this automatic backup and will fail on the conflict instead.

**Fix:** After the switch, verify the symlink is in place:

```sh
ls -la ~/.claude   # should point to ~/.nix-atelier/config/claude
```

If you have config in `~/.claude.bk` you want to keep, merge it into `~/.nix-atelier/config/claude` before deleting the backup.

______________________________________________________________________

## SSL errors from curl, AWS CLI, Python requests, or npm behind a TLS-inspecting proxy

**Symptom:** certificate-verification failures from Nix-managed tools specifically (system-packaged tools work fine), typically on a corporate network.

**Cause:** `env.nix` points Nix-managed tools at the system CA bundle (`SSL_CERT_FILE`, `NODE_EXTRA_CA_CERTS`, `REQUESTS_CA_BUNDLE`, all Linux/WSL2 only) because they don't inherit the system trust store the way distro-packaged binaries do. If the proxy's root CA isn't in that bundle yet, Nix-managed tools fail even though everything else on the machine is fine.

**Fix:** Install the CA into the system bundle the normal distro way (e.g. copy it into `/usr/local/share/ca-certificates/` and run `update-ca-certificates`), not into anything this repo manages. See [bootstrap.md](bootstrap.md)'s step 5 for details.

______________________________________________________________________

## `just` or `home-manager` not found during bootstrap

**Symptom:** `just: command not found` or `home-manager: command not found` on the first run.

**Cause:** These are installed by Home Manager: they aren't on PATH until after the first successful `switch`.

**Fix:** Use the full bootstrap command for the first apply. On macOS this
applies to `darwin-rebuild` too: nix-darwin has no separate installer, so
`darwin-rebuild` only exists *after* the first apply and the first one has to be
run straight from the flake:

```sh
# Linux / WSL2
nix run home-manager -- switch --flake .#<name> -b bk

# macOS, Apple Silicon
sudo nix --extra-experimental-features "nix-command flakes" \
  run nix-darwin -- switch --flake .#<name>
```

After the first apply, `home-manager`/`darwin-rebuild` are on PATH and you can use the short form directly: `home-manager switch --flake .#<name>` or `sudo darwin-rebuild switch --flake .#<name>`.

If you're working inside a clone of this repo itself (not a consumer flake scaffolded from `templates/default`), `just`/`nh` are also installed, and `just switch <profile>` detects the platform itself and applies via `nh home switch` or `nh darwin switch` accordingly:

```sh
just switch <profile>   # e.g. just switch minimal
just switch             # defaults to "full"
```

Pass the bare profile name (`just switch full`) on any machine and the right
suffix is appended for you: `-darwin` / `-darwin-aarch64` on macOS, `-aarch64`
on ARM Linux, nothing on x86_64 Linux. Passing an explicit name still works and
is honoured: it is just checked against the machine first, so an
architecture mismatch warns instead of silently building for the wrong platform,
and a macOS config name on Linux (or vice versa) is refused with the correct
name to use. `just rebuild` is an alias for the same recipe, not a macOS-only
variant.
