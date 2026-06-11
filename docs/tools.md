# Tool Reference

One-liner descriptions and links for every tool managed by this config, organized by category.

---

## Shell

### zsh
Default interactive shell. Configured with completions, aliases, and tool integrations. [zsh.org](https://www.zsh.org)

### bash
Fallback shell, configured with the same aliases and Nix init as zsh. [gnu.org/software/bash](https://www.gnu.org/software/bash/)

### starship
Cross-shell prompt showing git status, language versions, AWS region, and command duration. [starship.rs](https://starship.rs)

### zoxide
Smarter `cd` — learns your most-used directories; `z <partial>` jumps instantly. [github.com/ajeetdsouza/zoxide](https://github.com/ajeetdsouza/zoxide)

### atuin
Shell history synced across machines, searchable with fuzzy find (Ctrl-R). [atuin.sh](https://atuin.sh)

### fzf
General-purpose fuzzy finder; powers Ctrl-T (file), Ctrl-R (history), and Alt-C (directory). [github.com/junegunn/fzf](https://github.com/junegunn/fzf)

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
TUI git client — stage hunks, rebase interactively, manage branches visually. [github.com/jesseduffield/lazygit](https://github.com/jesseduffield/lazygit)

### jq
JSON processor and query language for the command line. [jqlang.org](https://jqlang.org)

### wget
Non-interactive network downloader. [gnu.org/software/wget](https://www.gnu.org/software/wget/)

### neofetch
System info display for terminal screenshots. [github.com/dylanaraps/neofetch](https://github.com/dylanaraps/neofetch)

---

## Git

### git-lfs
Git extension for versioning large files (models, datasets) outside the main repo. [git-lfs.com](https://git-lfs.com)

### gh
GitHub CLI — PRs, issues, workflows, and repo management from the terminal. [cli.github.com](https://cli.github.com)

### gitalias
Large collection of git aliases (e.g. `git la` for log, `git undo`). Managed as a git submodule fork. [github.com/GitAlias/gitalias](https://github.com/GitAlias/gitalias)

---

## Rust

### rust-overlay (stable + nightly)
Both stable and nightly Rust toolchains installed via [oxalica/rust-overlay](https://github.com/oxalica/rust-overlay). Switch with `rustup default nightly` or invoke directly with `cargo +nightly`. Updated on `nix-up`.

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

---

## Node

### nodejs
JavaScript runtime. Managed version pinned here; use fnm for per-project switching. [nodejs.org](https://nodejs.org)

### fnm
Fast Node version manager — `.nvmrc` auto-switching on `cd`. [github.com/Schniz/fnm](https://github.com/Schniz/fnm)

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

---

## AWS

### awscli2
Official AWS CLI v2 — interact with all AWS services from the terminal. [docs.aws.amazon.com/cli](https://docs.aws.amazon.com/cli/latest/userguide/)

### aws-vault
Secure AWS credential storage and session management; wraps the CLI to avoid plaintext credentials. [github.com/99designs/aws-vault](https://github.com/99designs/aws-vault)

---

## Shell Multiplexing

### tmux
Terminal multiplexer — persistent sessions, split panes, detach/reattach. Vi key bindings configured. [github.com/tmux/tmux](https://github.com/tmux/tmux)

---

## Environment Management

### home-manager
Manages the entire user environment declaratively via Nix. The tool that applies this config. [nix-community.github.io/home-manager](https://nix-community.github.io/home-manager/)

### direnv
Loads/unloads environment variables based on `.envrc` files when entering a directory. Integrates with Nix via `nix-direnv`. [direnv.net](https://direnv.net)

---

## GUI (gui-linux / gui-darwin profiles only)

### vscode
Code editor. Binary managed by Nix; extensions and settings via GitHub Settings Sync. [code.visualstudio.com](https://code.visualstudio.com)

### alacritty
GPU-accelerated terminal emulator. Configured with Fira Code font and VS Code-style colors. [alacritty.org](https://alacritty.org)

### obsidian
Markdown knowledge base. Notes repo is a separate clone. [obsidian.md](https://obsidian.md)
