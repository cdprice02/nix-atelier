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

### 2. Scaffold your config

```sh
mkdir ~/my-config && cd ~/my-config
nix flake init -t github:cdprice02/nix-atelier
$EDITOR flake.nix
```

Fill in `identity` (`username`, `name`, `email`, `github.user`) and at least
one entry under `configs`. **`username` must match your actual `$USER`**:
home-manager refuses to activate otherwise. See
`templates/default/README.md` (in [nix-atelier itself](https://github.com/cdprice02/nix-atelier/blob/main/templates/default/README.md))
for what every field accepts.

If you want a private overlay for a submodule this framework provisions
(e.g. a private Claude config), set `atelier.submodules` via your config's
`extraConfig`:

```nix
configs.home.full.extraConfig.atelier.submodules = {
  claude = "git@github.com:youruser/your-private-claude-config.git";
};
```

Home Manager activation will automatically add the `private` remote and check out a tracking branch in that submodule on first `switch`, once this repo's own `~/.nix-atelier` checkout exists locally too (see [issue #149](https://github.com/cdprice02/nix-atelier/issues/149): this specific mechanism still assumes one).

**HTTPS vs SSH:** you don't need to clone this repo at all to consume it (it's a flake input, fetched into the Nix store), but if you also want a local `~/.nix-atelier` checkout (for `claude`/`copilot`/`git-tools`' submodule symlinks, or to contribute to the framework), clone over HTTPS first: a `git@github.com:` remote needs an SSH key already registered with GitHub, and on a new machine you don't have one yet. This config *generates* that key for you, at step 7 below, during the first activation.

```sh
git clone --recurse-submodules https://github.com/cdprice02/nix-atelier.git ~/.nix-atelier
```

### 3. Set up secrets

Create `~/.config/secrets/env` and fill in your API keys (see
`secrets.env.example` in [nix-atelier](https://github.com/cdprice02/nix-atelier/blob/main/secrets.env.example) for the exact format):

```sh
mkdir -p ~/.config/secrets
cat > ~/.config/secrets/env <<'EOF'
export GITHUB_PERSONAL_ACCESS_TOKEN=""
EOF
$EDITOR ~/.config/secrets/env
```

This file is sourced by every shell session. It is gitignored and never committed.

**Optional: sops-nix instead of the manual copy above.** Off unless your
config's `extraConfig` sets `atelier.sops.file`; there's no separate on/off
flag. Only worth it if you want secrets encrypted in git rather than living
purely as an unmanaged local file. This repo's own `secrets/secrets.yaml.example`
is not something you point `atelier.sops.file` at directly: it's encrypted
for a placeholder recipient nobody holds the private half of, so it exists
purely to show the shape. Your real file belongs in your own private config
repo instead, never here.

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

In your `flake.nix`:

```nix
configs.home.full.extraConfig.atelier.sops = {
  secrets = ["GITHUB_PERSONAL_ACCESS_TOKEN" "MY_SERVICE_PAT"];  # whatever names you used above
  file = "/absolute/path/to/your-private-repo/secrets.yaml";
};
```

`home-manager switch` then renders those vars straight to
`~/.config/secrets/env` from your `atelier.sops.file`: the manual copy/fill step
above becomes unnecessary. To edit the encrypted values later: `sops secrets.yaml` in your private repo (opens `$EDITOR` with the decrypted
plaintext; saving re-encrypts automatically). If a token genuinely differs
between two of your machines, give each machine's config its own
`atelier.sops.file` pointing at a separate encrypted file, rather than sharing one.

### 4. Corporate or self-signed CA certificate (if applicable)

`env.nix` points Nix-managed tools (curl, AWS CLI, Python `requests`, npm) at
the system CA bundle (`/etc/ssl/certs/ca-certificates.crt` on Linux/WSL2) via
`SSL_CERT_FILE`, `NODE_EXTRA_CA_CERTS`, and `REQUESTS_CA_BUNDLE`: Nix-built
binaries don't inherit the system trust store automatically the way
distro-packaged ones do. If your network sits behind a TLS-inspecting proxy,
install the corporate root CA into that system bundle the normal distro way
(e.g. `update-ca-certificates` after copying it into
`/usr/local/share/ca-certificates/`), and nothing in this repo needs to know
about it separately.

### 5. Set default shell to zsh (optional, one-time)

Home Manager installs zsh but does not change the login shell: do this manually once:

```sh
_zsh="$(readlink -f ~/.nix-profile/bin/zsh)"
echo "$_zsh" | sudo tee -a /etc/shells
sudo chsh -s "$_zsh" <username>
```

After the next login the default shell will be zsh.

### 6. Apply your config

Use the config name you gave it in `flake.nix` (`full` in the example above).

```sh
nix flake check                                          # validate first
nix run home-manager -- switch --flake .#full -b bk
```

> **`-b bk` is required on the first switch** of any machine that already has
> shell dotfiles. Home Manager refuses to overwrite an existing `~/.bashrc`,
> `~/.profile`, `~/.zshrc` etc. and aborts with `Existing file '...' would be clobbered`. Nearly every distro (and WSL2) ships those from `/etc/skel`, so
> this is the normal case, not the exception. `-b bk` renames each conflicting
> file to `<name>.bk` instead of failing.

After first apply, `home-manager` is on PATH:

```sh
# subsequent applies
home-manager switch --flake .#full
```

If you're working inside a clone of this repo itself (not a separate
consumer directory), `just`/`nh` are also available: `just switch <name>`
detects the platform and applies via `nh`, printing a package/closure diff
before activating. Trailing args pass through: `just switch full -n` shows
the diff without activating, `just switch full -a` pauses for confirmation
first.

### 7. SSH key

The activation script generates `~/.ssh/<sshKey>` (ed25519, passphraseless) if it does not
exist. After first apply, add the public key to GitHub:

```sh
cat ~/.ssh/<sshKey>.pub
# Paste at: https://github.com/settings/keys
```

`<sshKey>` is the prefix of your identity's email (derived automatically from
the `email` field in your `flake.nix`).

### 8. Activate pre-commit hooks (contributors to this framework only)

Not part of consuming this framework: `pre-commit`/`.pre-commit-config.yaml`
are this repo's own dev tooling, not something a scaffolded config directory
has. Skip this step unless you're also working inside a clone of nix-atelier
itself, e.g. to submit a framework improvement (see CONTRIBUTING.md).

`pre-commit` is installed by the `full` tier: no separate install needed.
After first `home-manager switch` inside a clone of this repo, wire up the
hooks for that clone:

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
features" step here: the apply command in step 6 passes
`--extra-experimental-features` itself. That is deliberate: the flake features
have to be enabled *for root*, since the apply runs under `sudo`, and writing
`~/.config/nix/nix.conf` would only affect your own user. Once nix-darwin has
run once it manages `/etc/nix/nix.conf` for you (`system/darwin.nix` sets
`nix.settings.experimental-features`), so the flag is only needed for the very
first apply.

### 2. Scaffold your config

```sh
mkdir ~/my-config && cd ~/my-config
nix flake init -t github:cdprice02/nix-atelier
$EDITOR flake.nix
```

Fill in `identity`, and `configs.darwin.<name>.system`: `aarch64-darwin` for
Apple Silicon, `x86_64-darwin` for Intel (check with `uname -m`: `arm64` means
Apple Silicon, `x86_64` means Intel). They're not interchangeable: this
repo's own Intel config is pinned to nixpkgs 25.05, because
nixpkgs-unstable has dropped x86_64-darwin; Apple Silicon rides the same
rolling inputs as Linux. Picking the wrong one gets you a build for the wrong
platform, not a slower build of the right one. See the WSL2 section's step 2
above for the `submodules`/private-overlay pattern, which works the same way
here.

### 3. Set up secrets

```sh
mkdir -p ~/.config/secrets
cat > ~/.config/secrets/env <<'EOF'
export GITHUB_PERSONAL_ACCESS_TOKEN=""
EOF
$EDITOR ~/.config/secrets/env
```

See the WSL2 section's step 3 above for the sops-nix alternative, which works the same way here.

### 4. Corporate or self-signed CA certificate (if applicable)

**Not needed on macOS**: it trusts certs added to the system keychain, not an
env-var-pointed bundle the way Linux/WSL2's `env.nix` does (see the Linux
section's step 4). Skip straight to Apply below.

### 5. Pick your config name

Whatever you named your darwin config in step 2 (`full-darwin-aarch64` in
this repo's own convention, but any name works: it's just an attribute name
in `configs.darwin`).

### 6. Apply

`darwin-rebuild` does not exist yet: nix-darwin has no separate installer, so
the very first apply runs it straight from the flake:

```sh
sudo nix --extra-experimental-features "nix-command flakes" \
  run nix-darwin -- switch --flake .#<name>
```

After that first apply, `darwin-rebuild` is on PATH and every later apply is just:

```sh
sudo darwin-rebuild switch --flake .#<name>
```

If you're working inside a clone of this repo itself, `just switch` also
works: it detects OS and architecture, appends the right suffix, and applies
via `nh`, printing a diff before activating.

There's no separate "set default shell" step here the way WSL2 has one: nix-darwin's `system/darwin.nix` sets `programs.zsh.enable = true` at the system level, which (unlike standalone home-manager) registers zsh as an available login shell automatically.

### 7. SSH key

The activation script generates `~/.ssh/<sshKey>` (ed25519, passphraseless) if it does not
exist. After first apply, add the public key to GitHub:

```sh
cat ~/.ssh/<sshKey>.pub
# Paste at: https://github.com/settings/keys
```

`<sshKey>` is the prefix of your identity's email (derived automatically from
the `email` field in your `flake.nix`).

### 8. Activate pre-commit hooks (contributors to this framework only)

Not part of consuming this framework, same as the WSL2 section's equivalent
step: skip unless you're also working inside a clone of nix-atelier itself.

`pre-commit` is installed by the `full` tier: no separate install needed.
After first `darwin-rebuild switch` inside a clone of this repo, wire up the
hooks for that clone:

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

To actually deploy NixOS with this framework, scaffold a config the same way
as WSL2/macOS above (`nix flake init -t github:cdprice02/nix-atelier`), but
set `configs.nixos.<name>` instead, pointing `hardwareModule` at your own machine's real
`hardware-configuration.nix` (generate one with `nixos-generate-config`, the
standard NixOS tool, on the target machine). There is no bootstrap walkthrough
here the way WSL2/macOS have one above, because nobody has run this against
real NixOS hardware yet to write one accurately.
