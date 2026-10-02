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

### neovim
Daily-driver editor, and `$EDITOR`/`$VISUAL` wherever the `neovim` feature is on. Config is the `config/nvim` submodule ([cdprice02/nvim-config](https://github.com/cdprice02/nvim-config)), symlinked to `~/.config/nvim`; plugins are pinned by its own `lazy-lock.json`, while language servers and formatters come from Nix. [neovim.io](https://neovim.io)

### tree-sitter
Parser generator CLI. nvim-treesitter's main branch (Neovim 0.12+) needs it to build syntax parsers locally. [tree-sitter.github.io](https://tree-sitter.github.io/tree-sitter/)

### gcc
C compiler for nvim-treesitter's parsers and telescope-fzf-native, so neither depends on a system compiler being present (none on a fresh macOS without the Xcode tools). [gcc.gnu.org](https://gcc.gnu.org)

### make
Builds telescope-fzf-native's native sorter when lazy.nvim installs it. [gnu.org/software/make](https://www.gnu.org/software/make/)

### basedpyright
Python language server for Neovim (hover, go-to-definition, type checking, inlay hints): the open-source Pyright fork standing in for VS Code's Pylance, with the same settings ported. Ruff's own server handles linting alongside it. [docs.basedpyright.com](https://docs.basedpyright.com)

### lua-language-server
Lua language server, for editing the Neovim config itself. [luals.github.io](https://luals.github.io)

### prettierd
Prettier as a background daemon, so format-on-save in Neovim is instant: formats JSON, YAML and Markdown, with VS Code's `quoteProps`/`trailingComma` settings as the default for projects without their own `.prettierrc`. [github.com/fsouza/prettierd](https://github.com/fsouza/prettierd)

### stylua
Lua formatter; formats the Neovim config on save. [github.com/JohnnyMorganz/StyLua](https://github.com/JohnnyMorganz/StyLua)

### shfmt
Shell script formatter (bash, POSIX sh), run by Neovim on save. [github.com/mvdan/sh](https://github.com/mvdan/sh)

### taplo
TOML formatter and language server for Neovim: formats on save, and validates/completes `pyproject.toml`, `Cargo.toml` and friends against SchemaStore. Replaces VS Code's Even Better TOML. [taplo.tamasfe.dev](https://taplo.tamasfe.dev)

### vscode-langservers-extracted
VS Code's own JSON, HTML and CSS language servers, extracted for other editors. Neovim uses them with SchemaStore's JSON schemas. [github.com/hrsh7th/vscode-langservers-extracted](https://github.com/hrsh7th/vscode-langservers-extracted)

### yaml-language-server
YAML language server: validation and completion for GitHub workflows, compose files, CI configs and more, against SchemaStore. [github.com/redhat-developer/yaml-language-server](https://github.com/redhat-developer/yaml-language-server)

### marksman
Markdown language server: heading/link completion, go-to-definition across wiki-style links, broken-link diagnostics. [github.com/artempyanykh/marksman](https://github.com/artempyanykh/marksman)

### bash-language-server
Shell language server for Neovim, including Slurm batch scripts; surfaces shellcheck's lints as diagnostics. [github.com/bash-lsp/bash-language-server](https://github.com/bash-lsp/bash-language-server)

### shellcheck
Shell script linter, run by bash-language-server as you edit. [shellcheck.net](https://www.shellcheck.net)

### clang-tools (`clangd`)
C/C++ language server for Neovim, mainly for QMK keymaps (`qmk generate-compilation-database` gives it the include paths). [clangd.llvm.org](https://clangd.llvm.org)

### vim
Always-present fallback editor, and `$EDITOR` on profiles without the `neovim` feature. [vim.org](https://www.vim.org)

### nixd
Nix language server: completions, go-to-definition, and diagnostics for editing this repo's own `.nix` files. [github.com/nix-community/nixd](https://github.com/nix-community/nixd)

### nixfmt-rfc-style
The official RFC 166 Nix formatter. This repo's `nix fmt` runs it via treefmt (see treefmt.nix), alongside statix/deadnix/mdformat; also on PATH here directly for Claude Code's format-on-edit hook. [github.com/NixOS/nixfmt](https://github.com/NixOS/nixfmt)

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

### rust-overlay (nightly toolchain)
Single nightly Rust toolchain via oxalica/rust-overlay: `rustc`, `cargo`, `clippy`, `rustfmt`, `rust-analyzer`, and `rust-src` all from the same build, floating to the newest nightly date with all of those extensions available. [github.com/oxalica/rust-overlay](https://github.com/oxalica/rust-overlay)

### cargo-edit
Adds `cargo add`, `cargo rm`, `cargo upgrade` for managing dependencies. [github.com/killercup/cargo-edit](https://github.com/killercup/cargo-edit)

### watchexec
General-purpose file-watcher that reruns any command on change, not limited to cargo; supersedes cargo-watch. [github.com/watchexec/watchexec](https://github.com/watchexec/watchexec)

### cargo-seek
Searches crates.io from the terminal and helps pick a dependency version. [github.com/anlumo/cargo-seek](https://github.com/anlumo/cargo-seek)

### cargo-generate
Scaffolds a new project from a git-hosted template (`cargo generate --git <repo>`). [github.com/cargo-generate/cargo-generate](https://github.com/cargo-generate/cargo-generate)

### cargo-shear
Finds and removes unused dependencies across a Cargo workspace. [github.com/Boshen/cargo-shear](https://github.com/Boshen/cargo-shear)

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

### jupytext
Converts Jupyter notebooks to and from plain `# %%` scripts; Neovim opens `.ipynb` files through it, keeping outputs on save. [jupytext.readthedocs.io](https://jupytext.readthedocs.io)

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

### websocat
Websocket client, for the parts of the Home Assistant API with no REST equivalent: entity/device registry edits, Lovelace resource management, and reading persistent notifications (no longer entities, so `/api/states` cannot see them). [github.com/vi/websocat](https://github.com/vi/websocat)

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

### tmux-sessionizer
ThePrimeagen's session-per-project flow (`prefix f`, or `<C-f>` in Neovim): fuzzy-pick a repo and create or switch to a tmux session named after it. Searches `$TMUX_SESSIONIZER_DIRS` (colon-separated), defaulting to `~/repos`, this repo's own checkout plus its `config/` submodules, and every `atelier.configRepos` clone. [github.com/ThePrimeagen/tmux-sessionizer](https://github.com/ThePrimeagen/tmux-sessionizer)

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

### nh
Wraps darwin-rebuild/home-manager for `just switch`, printing a package/closure diff before activating. [github.com/nix-community/nh](https://github.com/nix-community/nh)

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
