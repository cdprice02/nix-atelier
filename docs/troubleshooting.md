# Troubleshooting

Common first-boot failures and how to fix them.

---

## `--impure` omitted → cryptic eval error

**Symptom:** `nix flake` or `home-manager switch` errors with something like:

```text
error: … builtins.getEnv "HOME" evaluated to ""
```

**Fix:** Every `home-manager switch` and `darwin-rebuild switch` requires `--impure`. At first bootstrap, `home-manager` may not be on PATH yet — use the `nix run` form:

```sh
# First bootstrap (home-manager not yet on PATH)
nix run home-manager -- switch --flake ~/.nix-config#<profile> --impure

# Subsequent applies
home-manager switch --flake ~/.nix-config#<profile> --impure
sudo darwin-rebuild switch --flake ~/.nix-config#<profile> --impure
```

`user.nix` is read from the filesystem via `builtins.getEnv "HOME"`, which is an impure operation. This flag is always needed, not just at bootstrap.

---

## Submodule directories empty after clone

**Symptom:** `~/.nix-config/config/claude/` is empty, or Home Manager errors on the symlink activation step.

**Cause:** The repo was cloned without `--recurse-submodules`.

**Fix:**

```sh
git -C ~/.nix-config submodule update --init --recursive
```

Or clone correctly from the start:

```sh
git clone --recurse-submodules git@github.com:cdprice02/nix-config.git ~/.nix-config
```

---

## SSH key not added to GitHub → submodule fetch fails

**Symptom:** During `home-manager switch`, the activation script prints:

```text
WARNING: submodule claude: fetch from private remote failed.
  Ensure your SSH key is added to GitHub, then rerun: home-manager switch --flake ~/.nix-config --impure
```

**Fix:**

```sh
# Print your public key
cat ~/.ssh/<sshKey>.pub

# Paste it at: https://github.com/settings/keys
# Then re-run:
home-manager switch --flake ~/.nix-config#<profile> --impure
```

`<sshKey>` is the prefix of your personal email from `user.nix` (e.g. `you` for `you@example.com`).

---

## Home Manager symlink conflict (`~/.claude` already exists)

**Symptom:** Home Manager warns about a backup file or fails to create `~/.claude`.

**Cause:** `~/.claude` exists as a real directory (e.g. from a previous manual install) rather than a symlink. Home Manager uses `backupFileExtension = "bk"` to handle conflicts, so it will rename the existing path to `~/.claude.bk`.

**Fix:** After the switch, verify the symlink is in place:

```sh
ls -la ~/.claude   # should point to ~/.nix-config/config/claude
```

If you have config in `~/.claude.bk` you want to keep, merge it into `~/.nix-config/config/claude` before deleting the backup.

---

## `~/.certs/corporate.pem` missing on work profile

**Symptom:** SSL errors from curl, AWS CLI, Python requests, or npm after applying a `work` profile. The activation script also warns:

```text
WARNING: ~/.certs/corporate.pem not found — see docs/bootstrap.md
```

**Fix:** Obtain the corporate root CA from your IT team and place it at `~/.certs/corporate.pem`:

```sh
mkdir -p ~/.certs
cp /path/to/corporate-root-ca.crt ~/.certs/corporate.pem
```

Then re-run `home-manager switch` to rebuild the combined bundle. See [bootstrap.md](bootstrap.md) for details.

---

## `just` or `home-manager` not found during bootstrap

**Symptom:** `just: command not found` or `home-manager: command not found` on the first run.

**Cause:** These are installed by Home Manager — they aren't on PATH until after the first successful `switch`.

**Fix:** Use the full bootstrap command for the first apply:

```sh
# Linux / WSL2
nix run home-manager -- switch --flake ~/.nix-config#<profile> --impure

# macOS
sudo darwin-rebuild switch --flake ~/.nix-config#<profile> --impure
```

After the first apply, `just` and `home-manager` are on PATH and you can use the short forms:

```sh
just switch PROFILE=<profile>   # Linux
just rebuild PROFILE=<profile>  # macOS
```
