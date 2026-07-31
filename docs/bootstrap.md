# Bootstrap Guide

First-time setup checklist per target machine.

---

## WSL2 (Linux, single-user Nix)

### 1. Install Nix (single-user)

```sh
sh <(curl -L https://nixos.org/nix/install) --no-daemon
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
. ~/.nix-profile/etc/profile.d/nix.sh
```

### 2. Clone the repo

```sh
git clone --recurse-submodules https://github.com/cdprice02/nix-config.git ~/.nix-config
```

**HTTPS, not SSH, deliberately.** A `git@github.com:` remote needs an SSH key
already registered with GitHub — and on a new machine you don't have one yet.
This config *generates* that key for you, at step 8 below, during the first
activation. Cloning over SSH here would be a chicken-and-egg: the key you'd need
is produced by the thing you're trying to clone. HTTPS needs no credentials for
a public repo. Switch the remote to SSH afterwards if you prefer, once step 8
has run and you've added the key to GitHub.

If you've forked this repo, clone **your fork's** URL instead — everything below
works the same, and `user.nix` keeps your identity out of the repo either way.

This also clones `config/claude` (Claude Code config), `config/copilot` (Copilot config, personal only), and `config/git/gitalias`. Home Manager symlinks these into `~` on first activation.

If you forgot `--recurse-submodules`, initialize them after the fact:

```sh
git -C ~/.nix-config submodule update --init --recursive
```

### 3. Set up local identity

Copy the example and fill in your values before running home-manager:

```sh
cp ~/.nix-config/user.nix.example ~/.nix-config/user.nix
$EDITOR ~/.nix-config/user.nix
```

`user.nix` is gitignored and never committed. Each machine has its own copy. Set `username`, `name`, `email`, and `work` identity. If you have a private overlay for any submodule (e.g. work-specific Claude config), add it to the `submodules` block:

```nix
submodules = {
  claude = "git@github.com:youruser/your-private-claude-config.git";
};
```

Home Manager activation will automatically add the `private` remote and check out a tracking branch in that submodule on first `switch`.

### 4. Set up secrets

Create the secrets file from the template and fill in your API keys:

```sh
mkdir -p ~/.config/secrets
cp ~/.nix-config/secrets.env.example ~/.config/secrets/env
$EDITOR ~/.config/secrets/env
```

This file is sourced by every shell session. It is gitignored and never committed.

**Optional: sops-nix instead of the manual copy above.** Off by default — only
worth it if you want secrets encrypted in git rather than living purely as an
unmanaged local file. Set `useSops = true;` in `user.nix`, then before your
first `switch` with it enabled:

```sh
mkdir -p ~/.config/sops/age && chmod 700 ~/.config/sops/age
# write your own age private key here (see .sops.yaml for which public key
# secrets/secrets.yaml is currently encrypted for)
$EDITOR ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt
```

If you're forking this repo: `secrets/secrets.yaml` is encrypted for the
original author's age key, and sops has no way to re-key a file for a new
recipient without first decrypting it with an existing one — you can't
"re-encrypt for your key" without a key you don't have. Instead, generate
your own keypair with `age-keygen`, replace the recipient in `.sops.yaml`
with your own public key, delete `secrets/secrets.yaml`, and recreate it
with `sops secrets/secrets.yaml` (opens your `$EDITOR` on an empty file;
use `secrets.env.example`'s var names as a guide, save to encrypt).

`home-manager switch` then renders the same vars straight to
`~/.config/secrets/env` from `secrets/secrets.yaml` — the manual copy/fill
step above becomes unnecessary. To edit the encrypted values later:
`sops secrets/secrets.yaml` (opens your `$EDITOR` with the decrypted
plaintext; saving re-encrypts automatically).

### 5. Corporate CA certificate (work profile only)

The `work` profile sets `SSL_CERT_FILE`, `NODE_EXTRA_CA_CERTS`, and `REQUESTS_CA_BUNDLE`
to `~/.certs/corporate.pem`. This file is **never committed** — place it manually.

On a corporate WSL2 machine the bundle may already be present under
`/usr/local/share/ca-certificates/`. Check with your IT team for the exact path, then:

```sh
mkdir -p ~/.certs
cp /path/to/corporate-root-ca.crt ~/.certs/corporate.pem
```

The activation script will warn on each `home-manager switch` until the file is present.

### 6. Set default shell to zsh (optional, one-time)

Home Manager installs zsh but does not change the login shell — do this manually once:

```sh
_zsh="$(readlink -f ~/.nix-profile/bin/zsh)"
echo "$_zsh" | sudo tee -a /etc/shells
sudo chsh -s "$_zsh" <username>
```

After the next login the default shell will be zsh.

### 7. Apply the profile

Pick **one** profile that matches your machine — `work` for a work machine, `personal` for a personal machine.

```sh
nix run home-manager -- switch --flake ~/.nix-config#work --impure -b bk      # work machine
nix run home-manager -- switch --flake ~/.nix-config#personal --impure -b bk  # personal machine
```

> **`--impure` is always required** — every `home-manager switch` needs it, not just
> bootstrap. `user.nix` is gitignored and read from the filesystem via
> `builtins.getEnv "HOME"`, which is an impure operation in Nix.
>
> **`-b bk` is required on the first switch** of any machine that already has
> shell dotfiles. Home Manager refuses to overwrite an existing `~/.bashrc`,
> `~/.profile`, `~/.zshrc` etc. and aborts with `Existing file '...' would be
> clobbered`. Nearly every distro (and WSL2) ships those from `/etc/skel`, so
> this is the normal case, not the exception. `-b bk` renames each conflicting
> file to `<name>.bk` instead of failing. `just switch` passes it for you on
> every subsequent apply.

After first apply, `home-manager` and `just` are on PATH:

```sh
# subsequent applies
just switch work      # or: home-manager switch --flake ~/.nix-config#work --impure
just switch personal  # or: home-manager switch --flake ~/.nix-config#personal --impure
just switch           # uses user.nix's `profile` field if set, else "personal"

just --list  # shows all available commands
```

### 8. SSH key

The activation script generates `~/.ssh/<sshKey>` (ed25519, passphraseless) if it does not
exist. After first apply, add the public key to GitHub:

```sh
cat ~/.ssh/<sshKey>.pub
# Paste at: https://github.com/settings/keys
```

`<sshKey>` is the prefix of your personal email (derived automatically from `user.nix`).

### 9. Activate pre-commit hooks (dev profile only)

`pre-commit` is installed by the `dev` profile — no separate install needed. After first `home-manager switch`, wire up the hooks for this repo clone:

```sh
pre-commit install
```

This runs automatically on every `git commit` from that point on. To run all checks manually:

```sh
just precommit
```

(`just precommit` wraps `pre-commit run --all-files` in `nix develop` — the
alejandra and markdownlint hooks resolve against the devShell's PATH, so a bare
`pre-commit run` outside it uses the wrong tool versions or fails to find them.)

---

## macOS (nix-darwin)

### 1. Install Nix (multi-user)

```sh
sh <(curl -L https://nixos.org/nix/install)
```

Unlike the WSL2 section above, there is no separate "enable experimental
features" step here — the apply command in step 7 passes
`--extra-experimental-features` itself. That is deliberate: the flake features
have to be enabled *for root*, since the apply runs under `sudo`, and writing
`~/.config/nix/nix.conf` would only affect your own user. Once nix-darwin has
run once it manages `/etc/nix/nix.conf` for you (`system/darwin.nix` sets
`nix.settings.experimental-features`), so the flag is only needed for the very
first apply.

### 2. Clone the repo

```sh
git clone --recurse-submodules https://github.com/cdprice02/nix-config.git ~/.nix-config
```

### 3. Set up local identity

```sh
cp ~/.nix-config/user.nix.example ~/.nix-config/user.nix
$EDITOR ~/.nix-config/user.nix
```

### 4. Set up secrets

```sh
mkdir -p ~/.config/secrets
cp ~/.nix-config/secrets.env.example ~/.config/secrets/env
$EDITOR ~/.config/secrets/env
```

### 5. Corporate CA certificate (work profile only)

**Not needed on macOS** — `work.nix`'s CA-bundle env vars (`SSL_CERT_FILE`, `NODE_EXTRA_CA_CERTS`, `REQUESTS_CA_BUNDLE`) are Linux-only (`lib.mkIf (!pkgs.stdenv.isDarwin)`); macOS trusts corporate certs via the system keychain instead. Skip straight to Apply below.

### 6. Pick your config

macOS has two configs per context, and **they are not interchangeable** — pick by
your Mac's CPU:

| Your Mac | Personal | Work |
|----------|----------|------|
| Apple Silicon (M1/M2/M3/M4…) | `personal-darwin-aarch64` | `work-darwin-aarch64` |
| Intel | `personal-darwin` | `work-darwin` |

Check with `uname -m` — `arm64` means Apple Silicon, `x86_64` means Intel.

They differ by more than architecture: the Intel configs are pinned to nixpkgs
25.05, because nixpkgs-unstable has dropped x86_64-darwin. Apple Silicon rides
the same rolling inputs as Linux. Picking the wrong one gets you a build for the
wrong platform, not a slower build of the right one.

### 7. Apply

`darwin-rebuild` does not exist yet — nix-darwin has no separate installer, so
the very first apply runs it straight from the flake. Use the line matching your
Mac:

```sh
# Apple Silicon
sudo nix --extra-experimental-features "nix-command flakes" \
  run nix-darwin -- switch --flake ~/.nix-config#personal-darwin-aarch64 --impure

# Intel — note the pinned nix-darwin release, matching this repo's 25.05 pin
sudo nix --extra-experimental-features "nix-command flakes" \
  run nix-darwin/nix-darwin-25.05 -- switch --flake ~/.nix-config#personal-darwin --impure
```

After that first apply, `darwin-rebuild` is on PATH and every later apply is just:

```sh
just switch          # detects OS and architecture, appends the right suffix
# or, explicitly:
sudo darwin-rebuild switch --flake ~/.nix-config#personal-darwin-aarch64 --impure
```

There's no separate "set default shell" step here the way WSL2 has one: nix-darwin's `system/darwin.nix` sets `programs.zsh.enable = true` at the system level, which (unlike standalone home-manager) registers zsh as an available login shell automatically.

### 8. SSH key

The activation script generates `~/.ssh/<sshKey>` (ed25519, passphraseless) if it does not
exist. After first apply, add the public key to GitHub:

```sh
cat ~/.ssh/<sshKey>.pub
# Paste at: https://github.com/settings/keys
```

`<sshKey>` is the prefix of your personal email (derived automatically from `user.nix`).

### 9. Activate pre-commit hooks (dev profile only)

`pre-commit` is installed by the `dev` tier — no separate install needed (`personal-darwin`/`work-darwin` are always dev-tier). After first `darwin-rebuild switch`, wire up the hooks for this repo clone:

```sh
pre-commit install
```

This runs automatically on every `git commit` from that point on. To run all checks manually:

```sh
just precommit
```

(`just precommit` wraps `pre-commit run --all-files` in `nix develop` — the
alejandra and markdownlint hooks resolve against the devShell's PATH, so a bare
`pre-commit run` outside it uses the wrong tool versions or fails to find them.)

---

## NixOS

Not implemented yet (tracked in issue #5) — `flake.nix` has no
`nixosConfigurations` output to build on. It needs a `mkNixosConfig` helper
(analogous to `mkDarwinConfig`) plus a target machine's
`hardware-configuration.nix` before `sudo nixos-rebuild switch` would have
anything to point at.
