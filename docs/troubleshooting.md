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

## `nix run nix-darwin -- switch` fails with "Unexpected files in /etc, aborting activation"

**Symptom:** the very first darwin apply (`sudo nix run nix-darwin -- switch --flake .#<name>`, before `darwin-rebuild` exists) fails with a list of files nix-darwin refuses to overwrite, typically `/etc/nix/nix.conf`, `/etc/bashrc`, `/etc/zshrc`.

**Cause:** these files already exist from macOS's own defaults (`/etc/bashrc`, `/etc/zshrc`) or from step 1's Nix installer (`/etc/nix/nix.conf`), and nix-darwin refuses to silently clobber content it doesn't recognize as its own on a first activation.

**Fix:** exactly what the error message says: rename each listed file by appending `.before-nix-darwin`, then rerun the apply command.

```sh
sudo mv /etc/nix/nix.conf /etc/nix/nix.conf.before-nix-darwin
sudo mv /etc/bashrc /etc/bashrc.before-nix-darwin
sudo mv /etc/zshrc /etc/zshrc.before-nix-darwin
```

nix-darwin regenerates all three from your config on the switch that follows. This is a one-time, first-activation-only step: every later `darwin-rebuild switch` manages these files itself and won't hit this again.

______________________________________________________________________

## `darwin-rebuild switch` fails at "Homebrew bundle" with "Calling the `--cleanup` switch is disabled"

**Symptom:** activation runs most of the way (`setting up /etc`, `system defaults`, `restarting Dock`, `setting up launchd services`) and then stops at the Homebrew step:

```text
Homebrew bundle...
Error: Calling the `--cleanup` switch is disabled! There is no replacement.
```

Afterwards the machine is in a half-applied state that is easy to misread as a no-op: `/nix/var/nix/profiles/system` has already advanced to the new generation, but `/run/current-system` still points at the old one, and **Home Manager's user activation never ran** -- so none of your packages or dotfile symlinks are in place even though the system-level settings were applied.

**Cause:** Homebrew 7.0 removed the `--cleanup` switch from `brew bundle`. nix-darwin's `homebrew.onActivation.cleanup = "uninstall"` and `"zap"` both compile down to that switch, so any darwin config setting either one aborts on Homebrew 7 or newer. Nothing to do with your config's correctness, and not fixable by moving the nix-darwin pin: Homebrew is an unpinned external that updates itself during activation (`autoUpdate = true`).

**Fix:** this framework now ships `cleanup = "none"` in `system/darwin.nix`, so an up-to-date nix-atelier does not hit it. If you override that option in your own config, set it to `"none"` as well, then rerun the switch:

```sh
sudo darwin-rebuild switch --flake .#<name>
```

The rerun builds a fresh generation and completes activation, including the Home Manager step that was skipped.

**What you give up:** Homebrew is no longer declarative. A formula or cask removed from `brews`/`casks` stays installed rather than being uninstalled. The equivalent is a deliberate manual step, since it uninstalls anything not in the Brewfile:

```sh
brew bundle cleanup --force
```

______________________________________________________________________

## SSL errors from curl, AWS CLI, Python requests, or npm behind a TLS-inspecting proxy

**Symptom:** certificate-verification failures from Nix-managed tools specifically (system-packaged tools work fine), typically on a corporate network.

**Cause:** `env.nix` points Nix-managed tools at the system CA bundle (`SSL_CERT_FILE`, `NODE_EXTRA_CA_CERTS`, `REQUESTS_CA_BUNDLE`, all Linux/WSL2 only) because they don't inherit the system trust store the way distro-packaged binaries do. If the proxy's root CA isn't in that bundle yet, Nix-managed tools fail even though everything else on the machine is fine.

**Fix:** Install the CA into the system bundle the normal distro way (e.g. copy it into `/usr/local/share/ca-certificates/` and run `update-ca-certificates`), not into anything this repo manages. See [bootstrap.md](bootstrap.md)'s step 5 for details.

______________________________________________________________________

## VS Code's rust-analyzer stops starting after an extension auto-update

**Symptom:** the rust-analyzer status bar item stays stuck, and the extension's output log shows a `Bootstrap error: rust-analyzer Language Server is not available` on startup, even though the extension is installed and was working moments before.

**Cause:** the `rust-lang.rust-analyzer` VS Code extension bundles its own standalone server binary under a version-numbered directory (e.g. `rust-lang.rust-analyzer-0.3.3033-darwin-x64/server/rust-analyzer`). When the extension auto-updates, the old version's directory is deleted, but a VS Code window opened before the update keeps running the old extension-host code in memory until the window (or its extension host) restarts. That stale code still looks for the server binary at the old, now-deleted path.

**Fix:** reload the window (**Developer: Reload Window**) or quit and reopen VS Code. To remove this failure mode rather than just clearing it once, set `rust-analyzer.server.path` in VS Code user settings to `${userHome}/.nix-profile/bin/rust-analyzer`: this points the extension at the nix-managed binary instead of its own bundled one, so an extension update can never strand it again. It also keeps rust-analyzer's proc-macro expansion on the same rustc build that compiles the workspace, since proc-macro ABI is version-sensitive.

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
