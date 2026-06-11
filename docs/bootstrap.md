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
git clone --recurse-submodules git@github.com:cdprice02/nix-config.git ~/.nix-config
```

This also clones `config/claude` (Claude Code config), `config/copilot` (Copilot config, personal only), and `config/git/gitalias`. Home Manager symlinks these into `~` on first activation.

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

```sh
nix run home-manager -- switch --flake ~/.nix-config#work --impure      # work machine
nix run home-manager -- switch --flake ~/.nix-config#personal --impure  # personal machine
```

After first apply, `home-manager` is on PATH:

```sh
home-manager switch --flake ~/.nix-config#work --impure
# or use the alias:
nix-sw  # expands to: home-manager switch --flake ~/.nix-config --impure
```

> `--impure` is required because `user.nix` is gitignored and read directly from the
> filesystem via `builtins.getEnv "HOME"` — not tracked in the Nix store.

### 8. SSH key

The activation script generates `~/.ssh/<sshKey>` (ed25519, passphraseless) if it does not
exist. After first apply, add the public key to GitHub:

```sh
cat ~/.ssh/<sshKey>.pub
# Paste at: https://github.com/settings/keys
```

`<sshKey>` is the prefix of your personal email (derived automatically from `user.nix`).

---

## macOS (nix-darwin)

### 1. Install Nix (multi-user)

```sh
sh <(curl -L https://nixos.org/nix/install)
```

### 2. Clone the repo

```sh
git clone --recurse-submodules git@github.com:cdprice02/nix-config.git ~/.nix-config
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

### 5. Apply

```sh
sudo darwin-rebuild switch --flake ~/.nix-config#personal-darwin
```

---

## NixOS

Uncomment `nixosConfigurations` in `flake.nix`, add `hardware-configuration.nix`
for the target machine, then:

```sh
sudo nixos-rebuild switch --flake ~/.nix-config#personal-nixos
```
