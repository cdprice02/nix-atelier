# Bootstrap Guide

First-time setup checklist per target machine.

______________________________________________________________________

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
git clone --recurse-submodules https://github.com/cdprice02/nix-atelier.git ~/.nix-atelier
```

**HTTPS, not SSH, deliberately.** A `git@github.com:` remote needs an SSH key
already registered with GitHub: and on a new machine you don't have one yet.
This config *generates* that key for you, at step 8 below, during the first
activation. Cloning over SSH here would be a chicken-and-egg: the key you'd need
is produced by the thing you're trying to clone. HTTPS needs no credentials for
a public repo. Switch the remote to SSH afterwards if you prefer, once step 8
has run and you've added the key to GitHub.

If you've forked this repo, clone **your fork's** URL instead: everything below
works the same, and `user.nix` keeps your identity out of the repo either way.

This also clones `config/claude` (Claude Code config), `config/copilot` (Copilot config), and `config/git/gitalias`. Home Manager symlinks these into `~` on first activation.

If you forgot `--recurse-submodules`, initialize them after the fact:

```sh
git -C ~/.nix-atelier submodule update --init --recursive
```

### 3. Set up local identity

Copy the example and fill in your values before running home-manager:

```sh
cp ~/.nix-atelier/user.nix.example ~/.nix-atelier/user.nix
$EDITOR ~/.nix-atelier/user.nix
```

`user.nix` is gitignored and never committed. Each machine has its own copy. Set `username`, `name`, `email`, and `github`. **`username` must match your actual `$USER`**: home-manager refuses to activate otherwise. If you have a private overlay for any submodule (e.g. a private Claude config), add it to the `submodules` block:

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
cp ~/.nix-atelier/secrets.env.example ~/.config/secrets/env
$EDITOR ~/.config/secrets/env
```

This file is sourced by every shell session. It is gitignored and never committed.

**Optional: sops-nix instead of the manual copy above.** Off unless
`user.nix`'s `sopsFile` is set; there's no separate on/off flag. Only worth
it if you want secrets encrypted in git rather than living purely as an
unmanaged local file. This repo's own `secrets/secrets.yaml.example` is not
something you point `sopsFile` at directly: it's encrypted for a placeholder
recipient nobody holds the private half of, so it exists purely to show the
shape. Your real file belongs in your own private config repo instead
(e.g. alongside `extraModulePaths` modules), never here.

```sh
# 1. Generate your own age keypair
mkdir -p ~/.config/sops/age && chmod 700 ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt   # prints your public key
chmod 600 ~/.config/sops/age/keys.txt

# 2. In your own private repo: create .sops.yaml with your public key as the
#    recipient (see examples/private-config/.sops.yaml.example for the shape,
#    or this repo's own .sops.yaml), then:
sops secrets.yaml   # opens $EDITOR on a new file; save to encrypt
```

In `user.nix`:

```nix
secrets  = ["GITHUB_PERSONAL_ACCESS_TOKEN" "MY_SERVICE_PAT"];  # whatever names you used above
sopsFile = "/absolute/path/to/your-private-repo/secrets.yaml";
```

`home-manager switch` then renders those vars straight to
`~/.config/secrets/env` from your `sopsFile`: the manual copy/fill step
above becomes unnecessary. To edit the encrypted values later: `sops secrets.yaml` in your private repo (opens `$EDITOR` with the decrypted
plaintext; saving re-encrypts automatically). If a token genuinely differs
between two of your machines, give each machine's `user.nix` its own
`sopsFile` pointing at a separate encrypted file, rather than sharing one.

### 5. Corporate or self-signed CA certificate (if applicable)

`env.nix` points Nix-managed tools (curl, AWS CLI, Python `requests`, npm) at
the system CA bundle (`/etc/ssl/certs/ca-certificates.crt` on Linux/WSL2) via
`SSL_CERT_FILE`, `NODE_EXTRA_CA_CERTS`, and `REQUESTS_CA_BUNDLE`: Nix-built
binaries don't inherit the system trust store automatically the way
distro-packaged ones do. If your network sits behind a TLS-inspecting proxy,
install the corporate root CA into that system bundle the normal distro way
(e.g. `update-ca-certificates` after copying it into
`/usr/local/share/ca-certificates/`), and nothing in this repo needs to know
about it separately.

### 6. Set default shell to zsh (optional, one-time)

Home Manager installs zsh but does not change the login shell: do this manually once:

```sh
_zsh="$(readlink -f ~/.nix-profile/bin/zsh)"
echo "$_zsh" | sudo tee -a /etc/shells
sudo chsh -s "$_zsh" <username>
```

After the next login the default shell will be zsh.

### 7. Apply the profile

Pick **one** profile that matches your machine: `full` for the complete dev toolchain, `minimal` for a lean bootstrap. See [docs/profiles.md](profiles.md) for the full list, including the `-gui` and `-aarch64` variants.

```sh
nix run home-manager -- switch --flake ~/.nix-atelier#full --impure -b bk
```

> **`--impure` is always required**: every `home-manager switch` needs it, not just
> bootstrap. `user.nix` is gitignored and read from the filesystem via
> `builtins.getEnv "HOME"`, which is an impure operation in Nix.
>
> **`-b bk` is required on the first switch** of any machine that already has
> shell dotfiles. Home Manager refuses to overwrite an existing `~/.bashrc`,
> `~/.profile`, `~/.zshrc` etc. and aborts with `Existing file '...' would be clobbered`. Nearly every distro (and WSL2) ships those from `/etc/skel`, so
> this is the normal case, not the exception. `-b bk` renames each conflicting
> file to `<name>.bk` instead of failing. `just switch` passes it for you on
> every subsequent apply.

After first apply, `home-manager`, `just`, and `nh` are on PATH:

```sh
# subsequent applies
just switch full    # or: nh home switch -c full . -- --impure
just switch minimal # or: nh home switch -c minimal . -- --impure
just switch         # uses user.nix's `profile` field if set, else "full"
                    # (the -aarch64 suffix is added automatically on ARM)

just --list  # shows all available commands
```

`just switch` applies via `nh`, which prints a package/closure diff before
activating. Trailing args pass through: `just switch full -n` shows the diff
without activating, `just switch full -a` pauses for confirmation first.

### 8. SSH key

The activation script generates `~/.ssh/<sshKey>` (ed25519, passphraseless) if it does not
exist. After first apply, add the public key to GitHub:

```sh
cat ~/.ssh/<sshKey>.pub
# Paste at: https://github.com/settings/keys
```

`<sshKey>` is the prefix of your personal email (derived automatically from `user.nix`).

### 9. Activate pre-commit hooks (full tier only)

`pre-commit` is installed by the `full` tier: no separate install needed. After first `home-manager switch`, wire up the hooks for this repo clone:

```sh
pre-commit install
```

This runs automatically on every `git commit` from that point on. To run all checks manually:

```sh
just precommit
```

(`just precommit` wraps `pre-commit run --all-files` in `nix develop`: the
treefmt hook resolves against the devShell's PATH, so a bare
`pre-commit run` outside it uses the wrong tool version or fails to find it.)

______________________________________________________________________

## macOS (nix-darwin)

### 1. Install Nix (multi-user)

```sh
sh <(curl -L https://nixos.org/nix/install)
```

Unlike the WSL2 section above, there is no separate "enable experimental
features" step here: the apply command in step 7 passes
`--extra-experimental-features` itself. That is deliberate: the flake features
have to be enabled *for root*, since the apply runs under `sudo`, and writing
`~/.config/nix/nix.conf` would only affect your own user. Once nix-darwin has
run once it manages `/etc/nix/nix.conf` for you (`system/darwin.nix` sets
`nix.settings.experimental-features`), so the flag is only needed for the very
first apply.

### 2. Clone the repo

```sh
git clone --recurse-submodules https://github.com/cdprice02/nix-atelier.git ~/.nix-atelier
```

### 3. Set up local identity

```sh
cp ~/.nix-atelier/user.nix.example ~/.nix-atelier/user.nix
$EDITOR ~/.nix-atelier/user.nix
```

### 4. Set up secrets

```sh
mkdir -p ~/.config/secrets
cp ~/.nix-atelier/secrets.env.example ~/.config/secrets/env
$EDITOR ~/.config/secrets/env
```

### 5. Corporate or self-signed CA certificate (if applicable)

**Not needed on macOS**: it trusts certs added to the system keychain, not an
env-var-pointed bundle the way Linux/WSL2's `env.nix` does (see the Linux
section's step 5). Skip straight to Apply below.

### 6. Pick your config

macOS has two configs, one per CPU, and **they are not interchangeable**:

| Your Mac                     | Config                |
| ---------------------------- | --------------------- |
| Apple Silicon (M1/M2/M3/M4…) | `full-darwin-aarch64` |
| Intel                        | `full-darwin`         |

Check with `uname -m`: `arm64` means Apple Silicon, `x86_64` means Intel.

They differ by more than architecture: the Intel config is pinned to nixpkgs
25.05, because nixpkgs-unstable has dropped x86_64-darwin. Apple Silicon rides
the same rolling inputs as Linux. Picking the wrong one gets you a build for the
wrong platform, not a slower build of the right one.

### 7. Apply

`darwin-rebuild` does not exist yet: nix-darwin has no separate installer, so
the very first apply runs it straight from the flake. Use the line matching your
Mac:

```sh
# Apple Silicon
sudo nix --extra-experimental-features "nix-command flakes" \
  run nix-darwin -- switch --flake ~/.nix-atelier#full-darwin-aarch64 --impure

# Intel: note the pinned nix-darwin release, matching this repo's 25.05 pin
sudo nix --extra-experimental-features "nix-command flakes" \
  run nix-darwin/nix-darwin-25.05 -- switch --flake ~/.nix-atelier#full-darwin --impure
```

After that first apply, `darwin-rebuild` and `nh` are on PATH and every later apply is just:

```sh
just switch          # detects OS and architecture, appends the right suffix
                     # applies via nh, printing a diff before activating
# or, explicitly:
sudo darwin-rebuild switch --flake ~/.nix-atelier#full-darwin-aarch64 --impure
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

### 9. Activate pre-commit hooks (full tier only)

`pre-commit` is installed by the `full` tier: no separate install needed (`full-darwin`/`full-darwin-aarch64` are always `full` tier). After first `darwin-rebuild switch`, wire up the hooks for this repo clone:

```sh
pre-commit install
```

This runs automatically on every `git commit` from that point on. To run all checks manually:

```sh
just precommit
```

(`just precommit` wraps `pre-commit run --all-files` in `nix develop`: the
treefmt hook resolves against the devShell's PATH, so a bare
`pre-commit run` outside it uses the wrong tool version or fails to find it.)

______________________________________________________________________

## NixOS

Supported as a config kind (#5), build-verified only: this repo's own
`nixosConfigurations.full-nixos`/`full-nixos-aarch64` build against a
synthetic hardware fixture (`tests/fixtures/nixos-hardware-stub.nix`), not
real hardware -- there is none in this loop to test against, and these two
were never meant to run `nixos-rebuild switch` anywhere. `nix build .#nixosConfigurations.full-nixos.config.system.build.toplevel` proves the
config evaluates and builds; it proves nothing about booting or activation.

To actually deploy NixOS with this framework, call `lib.mkConfigs` from your
own flake (see `templates.default` once it lands) with `configs.nixos.<name>`
pointing `hardwareModule` at your own machine's real
`hardware-configuration.nix` (generate one with `nixos-generate-config`, the
standard NixOS tool, on the target machine). There is no bootstrap walkthrough
here the way WSL2/macOS have one above, because nobody has run this against
real NixOS hardware yet to write one accurately.
