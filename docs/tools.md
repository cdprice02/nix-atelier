# Tool Reference

One-liner descriptions and links for every tool managed by this config, organized by category.

---

## Shell

### zsh
Default interactive shell. Configured with completions, aliases, and tool integrations. [zsh.org](https://www.zsh.org)

### bash
Fallback shell, configured with the same aliases and Nix init as zsh. [gnu.org/software/bash](https://www.gnu.org/software/bash/)

### fish
Available alongside zsh/bash with fzf/zoxide integration; not set as anyone's login shell in this config. [fishshell.com](https://fishshell.com)

### caret
Zero-subprocess cross-shell prompt: directory, git branch, exit-status arrow. No per-render fork/exec (unlike starship/oh-my-posh). [github.com/cdprice02/caret](https://github.com/cdprice02/caret)

### zoxide
Smarter `cd`: learns your most-used directories; `z <partial>` jumps instantly. [github.com/ajeetdsouza/zoxide](https://github.com/ajeetdsouza/zoxide)

### fzf
General-purpose fuzzy finder; powers Ctrl-T (file), Ctrl-R (history, native widget), and Alt-C (directory). [github.com/junegunn/fzf](https://github.com/junegunn/fzf)

---

## Fonts

### Fira Code
Monospace font with programming ligatures; used by Alacritty and terminal apps generally. [github.com/tonsky/FiraCode](https://github.com/tonsky/FiraCode)

### Fira Code Nerd Font
Fira Code patched with Nerd Font glyphs (icons, powerline symbols) for terminal UIs that use them. [nerdfonts.com](https://www.nerdfonts.com)

---

## CLI Utilities

### ripgrep (`rg`)
Fast recursive search, respects `.gitignore`, drops in for grep. [github.com/BurntSushi/ripgrep](https://github.com/BurntSushi/ripgrep)

### fd
Fast and user-friendly `find` replacement. [github.com/sharkdp/fd](https://github.com/sharkdp/fd)

### bat
`cat` with syntax highlighting, line numbers, and git diff indicators. [github.com/sharkdp/bat](https://github.com/sharkdp/bat)

### eza
Modern `ls` replacement with color, icons, and tree view. [eza.rocks](https://eza.rocks)

### delta
Syntax-highlighted diff viewer; used by git as the default pager. [github.com/dandavison/delta](https://github.com/dandavison/delta)

### btop
Resource monitor (CPU, memory, disk, network) with a clean TUI. [github.com/aristocratos/btop](https://github.com/aristocratos/btop)

### lazygit
TUI git client: stage hunks, rebase interactively, manage branches visually. [github.com/jesseduffield/lazygit](https://github.com/jesseduffield/lazygit)

### jq
JSON processor and query language for the command line. [jqlang.org](https://jqlang.org)

### wget
Non-interactive network downloader. [gnu.org/software/wget](https://www.gnu.org/software/wget/)

### fastfetch
System info display for terminal screenshots. Actively maintained replacement for the archived neofetch. [github.com/fastfetch-cli/fastfetch](https://github.com/fastfetch-cli/fastfetch)

### hyperfine
Command-line benchmarking tool: statistically sound timing with warmup runs and outlier detection. [github.com/sharkdp/hyperfine](https://github.com/sharkdp/hyperfine)

### rsync
Fast incremental file transfer/sync over SSH or locally. [rsync.samba.org](https://rsync.samba.org)

### tree
Recursive directory listing as an indented tree. [oldmanprogrammer.net/source.php?dir=projects/tree](http://mama.indstate.edu/users/ice/tree/)

### ncdu
Interactive disk-usage analyzer: navigate directories by size, delete from within the TUI. [dev.yorhel.nl/ncdu](https://dev.yorhel.nl/ncdu)

### htop
Interactive process viewer: an ncurses `top` replacement. [htop.dev](https://htop.dev)

---

## Editor

### vim
Default `$EDITOR` for commit messages and quick edits. vscode is the daily-driver editor on GUI profiles; vim is the always-present fallback. [vim.org](https://www.vim.org)

### nixd
Nix language server: completions, go-to-definition, and diagnostics for editing this repo's own `.nix` files. [github.com/nix-community/nixd](https://github.com/nix-community/nixd)

### alejandra
Nix formatter: this repo's `nix fmt`, pre-commit hook, and CI lint all agree on it. Also on PATH for Claude Code's format-on-edit hook. [github.com/kamadorueda/alejandra](https://github.com/kamadorueda/alejandra)

---

## Git

### git
Version control. Configured with delta as the diff pager and gitalias's alias set. [git-scm.com](https://git-scm.com)

### git-lfs
Git extension for versioning large files (models, datasets) outside the main repo. [git-lfs.com](https://git-lfs.com)

### gh
GitHub CLI: PRs, issues, workflows, and repo management from the terminal. [cli.github.com](https://cli.github.com)

### pre-commit
Manages git pre-commit hooks from a declarative `.pre-commit-config.yaml`; `pre-commit install` wires this repo's own hooks. [pre-commit.com](https://pre-commit.com)

### glab
GitLab CLI: MRs, issues, pipelines, and repo management from the terminal. [gitlab.com/gitlab-org/cli](https://gitlab.com/gitlab-org/cli)

### difftastic
Structural (AST-aware) diff tool. Wired as an explicit `git difftool -t difftastic`, not the default: works without vscode, so it's available on headless dev profiles too. [github.com/Wilfred/difftastic](https://github.com/Wilfred/difftastic)

### git-filter-repo
Rewrites git history: mailmaps, path filtering, blob removal. The supported replacement for `git filter-branch`. [github.com/newren/git-filter-repo](https://github.com/newren/git-filter-repo)

### gitalias
Large collection of git aliases (e.g. `git la` for log, `git undo`). Managed as a git submodule fork, wired in via `programs.git.includes`: not a Nix package. [github.com/GitAlias/gitalias](https://github.com/GitAlias/gitalias)

---

## Rust

### rust-overlay (stable toolchain + nightly rust-analyzer/rustfmt)
Stable Rust toolchain (`rustc`, `cargo`, `clippy`) via oxalica/rust-overlay is the daily-driver default. `rust-analyzer` and `rustfmt` are pinned to nightly instead, pulled as individual components so nightly never puts a second `rustc`/`cargo` on `PATH`. `rust-src` travels with `rust-analyzer`, not the stable toolchain: stable and nightly `rust-src` have different internal layouts, and a mismatch breaks std-type resolution in the editor. `clippy` stays on stable since it lints whatever's actually compiled and shipped. [github.com/oxalica/rust-overlay](https://github.com/oxalica/rust-overlay)

### cargo-edit
Adds `cargo add`, `cargo rm`, `cargo upgrade` for managing dependencies. [github.com/killercup/cargo-edit](https://github.com/killercup/cargo-edit)

### cargo-watch
Reruns commands on file change (`cargo watch -x test`). [github.com/watchexec/cargo-watch](https://github.com/watchexec/cargo-watch)

### cargo-expand
Shows the output of macro expansion (`cargo expand`). [github.com/dtolnay/cargo-expand](https://github.com/dtolnay/cargo-expand)

### cargo-audit
Audits `Cargo.lock` against the RustSec advisory database. [github.com/rustsec/rustsec](https://github.com/rustsec/rustsec/tree/main/cargo-audit)

### samply
Command-line CPU profiler; records a Firefox Profiler-compatible trace. [github.com/mstange/samply](https://github.com/mstange/samply)

### cargo-nextest
Next-generation test runner (`cargo nextest run`): faster, better output, per-test isolation. [nexte.st](https://nexte.st)

### bacon
Background code checker: reruns `cargo check`/`test`/`clippy` on file change, in a dedicated terminal pane. [github.com/Canop/bacon](https://github.com/Canop/bacon)

---

## Node

### nodejs
JavaScript runtime. Managed version pinned here; use fnm for per-project switching. [nodejs.org](https://nodejs.org)

### fnm
Fast Node version manager: `.nvmrc` auto-switching on `cd`. [github.com/Schniz/fnm](https://github.com/Schniz/fnm)

### bun
Fast all-in-one JavaScript runtime, bundler, and package manager. [bun.sh](https://bun.sh)

---

## Python

### python3
Python interpreter. For project environments use `uv venv`. [python.org](https://www.python.org)

### uv
Extremely fast Python package and project manager; replaces pip, venv, and pip-tools. [docs.astral.sh/uv](https://docs.astral.sh/uv/)

### jupyterlab (`jupyter-lab`)
Browser-based notebooks for interactive computing and data exploration. [jupyter.org](https://jupyter.org)

### ipython
Enhanced interactive Python REPL with tab completion and magic commands. [ipython.org](https://ipython.org)

### ruff
Extremely fast Python linter and formatter, written in Rust; replaces flake8/black/isort. [docs.astral.sh/ruff](https://docs.astral.sh/ruff/)

### ty
Extremely fast Python type checker from Astral (uv/ruff's maintainers); still pre-1.0. [github.com/astral-sh/ty](https://github.com/astral-sh/ty)

### pixi
Cargo-style project/environment manager (conda-forge + PyPI packages, project-local lockfiles): chosen over conda/mamba for no base-environment management and reproducible lockfiles. [pixi.sh](https://pixi.sh)

---

## Data

### duckdb
In-process analytical (OLAP) SQL database: query CSV/Parquet/JSON files directly, no server to run. [duckdb.org](https://duckdb.org)

---

## AWS

### awscli2
Official AWS CLI v2: interact with all AWS services from the terminal. [docs.aws.amazon.com/cli](https://docs.aws.amazon.com/cli/latest/userguide/)

### aws-vault
Secure AWS credential storage and session management; wraps the CLI to avoid plaintext credentials. [github.com/99designs/aws-vault](https://github.com/99designs/aws-vault)

### s5cmd
High-performance S3 and local filesystem execution tool; parallel transfers far faster than the AWS CLI for bulk operations. [github.com/peak/s5cmd](https://github.com/peak/s5cmd)

### session-manager-plugin
AWS CLI plugin enabling `aws ssm start-session`: shell access to EC2 instances and port forwarding without SSH/bastion hosts. [docs.aws.amazon.com/systems-manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)

---

## Kubernetes

### kubectl
Kubernetes CLI: homelab k3s cluster ops. Kubeconfig lives at `~/.kube/config` (contains client certs, never committed, not Nix-managed). [kubernetes.io/docs/reference/kubectl](https://kubernetes.io/docs/reference/kubectl/)

### helm (`kubernetes-helm`)
Kubernetes package manager: install and manage chart releases. [helm.sh](https://helm.sh)

### helmfile
Declarative spec for deploying multiple Helm releases together. [github.com/helmfile/helmfile](https://github.com/helmfile/helmfile)

---

## Secrets

### sops
Encrypts/decrypts secrets in files using age or PGP recipients, keeping ciphertext safe to commit. [github.com/getsops/sops](https://github.com/getsops/sops)

### age
Simple, modern file encryption tool; the recipient/key mechanism sops uses here. [age-encryption.org](https://age-encryption.org)

### rbw
Maintained Rust Bitwarden CLI (official `bitwarden-cli` is marked broken in the current nixpkgs pin); its agent caches unlock for scripting. [github.com/doy/rbw](https://github.com/doy/rbw)

### pinentry-tty
Lets rbw prompt for the master password from the terminal (cross-platform; macOS has no pinentry by default). [gnupg.org/software/pinentry](https://gnupg.org/software/pinentry.html)

---

## Shell Multiplexing

### tmux
Terminal multiplexer: persistent sessions, split panes, detach/reattach. Vi key bindings configured. tmux-resurrect and tmux-continuum are also installed, so sessions survive a reboot: continuum wraps resurrect for automatic save and restore; neither works without the other. [github.com/tmux/tmux](https://github.com/tmux/tmux)

---

## Firmware

### qmk
QMK firmware CLI: compile and flash custom mechanical keyboard firmware (`qmk compile`, `qmk flash`). Dev profiles only. [qmk.fm](https://qmk.fm)

---

## Environment Management

### home-manager
Manages the entire user environment declaratively via Nix. The tool that applies this config. [nix-community.github.io/home-manager](https://nix-community.github.io/home-manager/)

### just
Task runner / discoverability layer for this repo's own commands (`just --list` shows all of them). [github.com/casey/just](https://github.com/casey/just)

### direnv
Loads/unloads environment variables based on `.envrc` files when entering a directory. Integrates with Nix via `nix-direnv`. [direnv.net](https://direnv.net)

---

## AI

### claude-code
Installed via its official native installer (curl-piped script), not npm or nixpkgs: ships multiple releases a week and self-updates in place, which nixpkgs packaging and Nix's rebuild cycle can't keep pace with. [claude.com/claude-code](https://claude.com/claude-code)

### GitHub Copilot CLI
Config symlinked from a git submodule (`config/copilot`), not a Nix package: the `copilot` feature just points `~/.copilot` at it. [github.com/github/copilot-cli](https://github.com/github/copilot-cli)

---

## GUI (gui-linux / gui-darwin profiles only)

### vscode
Code editor. Binary managed by Nix; extensions and settings via GitHub Settings Sync. [code.visualstudio.com](https://code.visualstudio.com)

### alacritty
GPU-accelerated terminal emulator. Configured with Fira Code font and VS Code-style colors. [alacritty.org](https://alacritty.org)

### obsidian
Markdown knowledge base. Notes repo is a separate clone. [obsidian.md](https://obsidian.md)

---
