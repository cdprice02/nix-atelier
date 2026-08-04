# Hand-curated tool metadata for the generated docs/tools.md. This is the one
# piece of the docs pipeline that genuinely can't be derived from Nix:
# descriptions/categories/links are human judgment, not facts extractable
# from nixpkgs (its own `meta.description` has no category concept and
# doesn't match this doc's tailored wording). What's no longer hand-written
# is whether this file is complete: the drift check in flake.nix asserts
# every package actually realized somewhere in this config's closures has an
# `entries` match here (or is in one of the two lists below), and vice versa.
#
# `matches` lists realized package identities, resolved the same way the
# drift-checker resolves them: `p.pname or p.name`. Usually a real nixpkgs
# attribute name, but sometimes synthetic (`lang-rust.nix`'s
# `pkgs.buildEnv { name = "rust-analyzer-nightly-bundle"; ... }` resolves to
# that literal string, not any real attribute) or HM-module-owned (enabling
# `programs.bash` realizes as `bash-interactive`, not `bash`). `key` is the
# doc heading text, independent of `matches`, since one heading sometimes
# covers several realized names (the stable + nightly Rust bundle) and
# sometimes reads better than the raw realized name (`bash-interactive` ->
# "bash").
{
  entries = [
    # ── Shell ──────────────────────────────────────────────────────────────
    {
      key = "zsh";
      matches = ["zsh"];
      category = "Shell";
      description = "Default interactive shell. Configured with completions, aliases, and tool integrations.";
      link = "[zsh.org](https://www.zsh.org)";
    }
    {
      key = "bash";
      matches = ["bash-interactive"];
      category = "Shell";
      description = "Fallback shell, configured with the same aliases and Nix init as zsh.";
      link = "[gnu.org/software/bash](https://www.gnu.org/software/bash/)";
    }
    {
      key = "fish";
      matches = ["fish"];
      category = "Shell";
      description = "Available alongside zsh/bash with fzf/zoxide integration; not set as anyone's login shell in this config.";
      link = "[fishshell.com](https://fishshell.com)";
    }
    {
      key = "caret";
      matches = ["caret"];
      category = "Shell";
      description = "Zero-subprocess cross-shell prompt: directory, git branch, exit-status arrow. No per-render fork/exec (unlike starship/oh-my-posh).";
      link = "[github.com/cdprice02/caret](https://github.com/cdprice02/caret)";
    }
    {
      key = "zoxide";
      matches = ["zoxide"];
      category = "Shell";
      description = "Smarter `cd`: learns your most-used directories; `z <partial>` jumps instantly.";
      link = "[github.com/ajeetdsouza/zoxide](https://github.com/ajeetdsouza/zoxide)";
    }
    {
      key = "fzf";
      matches = ["fzf"];
      category = "Shell";
      description = "General-purpose fuzzy finder; powers Ctrl-T (file), Ctrl-R (history, native widget), and Alt-C (directory).";
      link = "[github.com/junegunn/fzf](https://github.com/junegunn/fzf)";
    }

    # ── CLI Utilities ──────────────────────────────────────────────────────
    {
      key = "ripgrep (`rg`)";
      matches = ["ripgrep"];
      category = "CLI Utilities";
      description = "Fast recursive search, respects `.gitignore`, drops in for grep.";
      link = "[github.com/BurntSushi/ripgrep](https://github.com/BurntSushi/ripgrep)";
    }
    {
      key = "fd";
      matches = ["fd"];
      category = "CLI Utilities";
      description = "Fast and user-friendly `find` replacement.";
      link = "[github.com/sharkdp/fd](https://github.com/sharkdp/fd)";
    }
    {
      key = "bat";
      matches = ["bat"];
      category = "CLI Utilities";
      description = "`cat` with syntax highlighting, line numbers, and git diff indicators.";
      link = "[github.com/sharkdp/bat](https://github.com/sharkdp/bat)";
    }
    {
      key = "eza";
      matches = ["eza"];
      category = "CLI Utilities";
      description = "Modern `ls` replacement with color, icons, and tree view.";
      link = "[eza.rocks](https://eza.rocks)";
    }
    {
      key = "delta";
      matches = ["delta"];
      category = "CLI Utilities";
      description = "Syntax-highlighted diff viewer; used by git as the default pager.";
      link = "[github.com/dandavison/delta](https://github.com/dandavison/delta)";
    }
    {
      key = "btop";
      matches = ["btop"];
      category = "CLI Utilities";
      description = "Resource monitor (CPU, memory, disk, network) with a clean TUI.";
      link = "[github.com/aristocratos/btop](https://github.com/aristocratos/btop)";
    }
    {
      key = "lazygit";
      matches = ["lazygit"];
      category = "CLI Utilities";
      description = "TUI git client: stage hunks, rebase interactively, manage branches visually.";
      link = "[github.com/jesseduffield/lazygit](https://github.com/jesseduffield/lazygit)";
    }
    {
      key = "jq";
      matches = ["jq"];
      category = "CLI Utilities";
      description = "JSON processor and query language for the command line.";
      link = "[jqlang.org](https://jqlang.org)";
    }
    {
      key = "wget";
      matches = ["wget"];
      category = "CLI Utilities";
      description = "Non-interactive network downloader.";
      link = "[gnu.org/software/wget](https://www.gnu.org/software/wget/)";
    }
    {
      key = "fastfetch";
      matches = ["fastfetch"];
      category = "CLI Utilities";
      description = "System info display for terminal screenshots. Actively maintained replacement for the archived neofetch.";
      link = "[github.com/fastfetch-cli/fastfetch](https://github.com/fastfetch-cli/fastfetch)";
    }
    {
      key = "hyperfine";
      matches = ["hyperfine"];
      category = "CLI Utilities";
      description = "Command-line benchmarking tool: statistically sound timing with warmup runs and outlier detection.";
      link = "[github.com/sharkdp/hyperfine](https://github.com/sharkdp/hyperfine)";
    }

    # ── Editor ─────────────────────────────────────────────────────────────
    {
      key = "vim";
      matches = ["vim"];
      category = "Editor";
      description = "Default `\$EDITOR` for commit messages and quick edits. vscode is the daily-driver editor on GUI profiles; vim is the always-present fallback.";
      link = "[vim.org](https://www.vim.org)";
    }
    {
      key = "nixd";
      matches = ["nixd"];
      category = "Editor";
      description = "Nix language server: completions, go-to-definition, and diagnostics for editing this repo's own `.nix` files.";
      link = "[github.com/nix-community/nixd](https://github.com/nix-community/nixd)";
    }
    {
      key = "alejandra";
      matches = ["alejandra"];
      category = "Editor";
      description = "Nix formatter: this repo's `nix fmt`, pre-commit hook, and CI lint all agree on it. Also on PATH for Claude Code's format-on-edit hook.";
      link = "[github.com/kamadorueda/alejandra](https://github.com/kamadorueda/alejandra)";
    }

    # ── Data ───────────────────────────────────────────────────────────────
    {
      key = "duckdb";
      matches = ["duckdb"];
      category = "Data";
      description = "In-process analytical (OLAP) SQL database: query CSV/Parquet/JSON files directly, no server to run.";
      link = "[duckdb.org](https://duckdb.org)";
    }

    # ── Git ────────────────────────────────────────────────────────────────
    {
      key = "git";
      matches = ["git"];
      category = "Git";
      description = "Version control. Configured with delta as the diff pager and gitalias's alias set.";
      link = "[git-scm.com](https://git-scm.com)";
    }
    {
      key = "git-lfs";
      matches = ["git-lfs"];
      category = "Git";
      description = "Git extension for versioning large files (models, datasets) outside the main repo.";
      link = "[git-lfs.com](https://git-lfs.com)";
    }
    {
      key = "gh";
      matches = ["gh"];
      category = "Git";
      description = "GitHub CLI: PRs, issues, workflows, and repo management from the terminal.";
      link = "[cli.github.com](https://cli.github.com)";
    }
    {
      key = "pre-commit";
      matches = ["pre-commit"];
      category = "Git";
      description = "Manages git pre-commit hooks from a declarative `.pre-commit-config.yaml`; `pre-commit install` wires this repo's own hooks.";
      link = "[pre-commit.com](https://pre-commit.com)";
    }
    {
      key = "glab";
      matches = ["glab"];
      category = "Git";
      description = "GitLab CLI: MRs, issues, pipelines, and repo management from the terminal.";
      link = "[gitlab.com/gitlab-org/cli](https://gitlab.com/gitlab-org/cli)";
    }
    {
      key = "difftastic";
      matches = ["difftastic"];
      category = "Git";
      description = "Structural (AST-aware) diff tool. Wired as an explicit `git difftool -t difftastic`, not the default: works without vscode, so it's available on headless dev profiles too.";
      link = "[github.com/Wilfred/difftastic](https://github.com/Wilfred/difftastic)";
    }
    {
      key = "git-filter-repo";
      matches = ["git-filter-repo"];
      category = "Git";
      description = "Rewrites git history: mailmaps, path filtering, blob removal. The supported replacement for `git filter-branch`.";
      link = "[github.com/newren/git-filter-repo](https://github.com/newren/git-filter-repo)";
    }

    # ── Fonts ──────────────────────────────────────────────────────────────
    {
      key = "Fira Code";
      matches = ["fira-code"];
      category = "Fonts";
      description = "Monospace font with programming ligatures; used by Alacritty and terminal apps generally.";
      link = "[github.com/tonsky/FiraCode](https://github.com/tonsky/FiraCode)";
    }
    {
      key = "Fira Code Nerd Font";
      matches = ["nerd-fonts-fira-code"];
      category = "Fonts";
      description = "Fira Code patched with Nerd Font glyphs (icons, powerline symbols) for terminal UIs that use them.";
      link = "[nerdfonts.com](https://www.nerdfonts.com)";
    }

    # ── Server Tools ───────────────────────────────────────────────────────
    {
      key = "rsync";
      matches = ["rsync"];
      category = "Server Tools";
      description = "Fast incremental file transfer/sync over SSH or locally.";
      link = "[rsync.samba.org](https://rsync.samba.org)";
    }
    {
      key = "tree";
      matches = ["tree"];
      category = "Server Tools";
      description = "Recursive directory listing as an indented tree.";
      link = "[oldmanprogrammer.net/source.php?dir=projects/tree](http://mama.indstate.edu/users/ice/tree/)";
    }
    {
      key = "ncdu";
      matches = ["ncdu"];
      category = "Server Tools";
      description = "Interactive disk-usage analyzer: navigate directories by size, delete from within the TUI.";
      link = "[dev.yorhel.nl/ncdu](https://dev.yorhel.nl/ncdu)";
    }
    {
      key = "htop";
      matches = ["htop"];
      category = "Server Tools";
      description = "Interactive process viewer: an ncurses `top` replacement.";
      link = "[htop.dev](https://htop.dev)";
    }

    # ── Rust ───────────────────────────────────────────────────────────────
    {
      key = "rust-overlay (stable toolchain + nightly rust-analyzer/rustfmt)";
      matches = ["rust-minimal" "rust-analyzer-nightly-bundle"];
      category = "Rust";
      description = "Stable Rust toolchain (`rustc`, `cargo`, `clippy`) via oxalica/rust-overlay is the daily-driver default. `rust-analyzer` and `rustfmt` are pinned to nightly instead, pulled as individual components so nightly never puts a second `rustc`/`cargo` on `PATH`. `rust-src` travels with `rust-analyzer`, not the stable toolchain: stable and nightly `rust-src` have different internal layouts, and a mismatch breaks std-type resolution in the editor. `clippy` stays on stable since it lints whatever's actually compiled and shipped.";
      link = "[github.com/oxalica/rust-overlay](https://github.com/oxalica/rust-overlay)";
    }
    {
      key = "cargo-edit";
      matches = ["cargo-edit"];
      category = "Rust";
      description = "Adds `cargo add`, `cargo rm`, `cargo upgrade` for managing dependencies.";
      link = "[github.com/killercup/cargo-edit](https://github.com/killercup/cargo-edit)";
    }
    {
      key = "cargo-watch";
      matches = ["cargo-watch"];
      category = "Rust";
      description = "Reruns commands on file change (`cargo watch -x test`).";
      link = "[github.com/watchexec/cargo-watch](https://github.com/watchexec/cargo-watch)";
    }
    {
      key = "cargo-expand";
      matches = ["cargo-expand"];
      category = "Rust";
      description = "Shows the output of macro expansion (`cargo expand`).";
      link = "[github.com/dtolnay/cargo-expand](https://github.com/dtolnay/cargo-expand)";
    }
    {
      key = "cargo-audit";
      matches = ["cargo-audit"];
      category = "Rust";
      description = "Audits `Cargo.lock` against the RustSec advisory database.";
      link = "[github.com/rustsec/rustsec](https://github.com/rustsec/rustsec/tree/main/cargo-audit)";
    }
    {
      key = "samply";
      matches = ["samply"];
      category = "Rust";
      description = "Command-line CPU profiler; records a Firefox Profiler-compatible trace.";
      link = "[github.com/mstange/samply](https://github.com/mstange/samply)";
    }
    {
      key = "cargo-nextest";
      matches = ["cargo-nextest"];
      category = "Rust";
      description = "Next-generation test runner (`cargo nextest run`): faster, better output, per-test isolation.";
      link = "[nexte.st](https://nexte.st)";
    }
    {
      key = "bacon";
      matches = ["bacon"];
      category = "Rust";
      description = "Background code checker: reruns `cargo check`/`test`/`clippy` on file change, in a dedicated terminal pane.";
      link = "[github.com/Canop/bacon](https://github.com/Canop/bacon)";
    }

    # ── Node ───────────────────────────────────────────────────────────────
    {
      key = "nodejs";
      matches = ["nodejs"];
      category = "Node";
      description = "JavaScript runtime. Managed version pinned here; use fnm for per-project switching.";
      link = "[nodejs.org](https://nodejs.org)";
    }
    {
      key = "fnm";
      matches = ["fnm"];
      category = "Node";
      description = "Fast Node version manager: `.nvmrc` auto-switching on `cd`.";
      link = "[github.com/Schniz/fnm](https://github.com/Schniz/fnm)";
    }
    {
      key = "bun";
      matches = ["bun"];
      category = "Node";
      description = "Fast all-in-one JavaScript runtime, bundler, and package manager.";
      link = "[bun.sh](https://bun.sh)";
    }

    # ── Python ─────────────────────────────────────────────────────────────
    {
      key = "python3";
      matches = ["python3"];
      category = "Python";
      description = "Python interpreter. For project environments use `uv venv`.";
      link = "[python.org](https://www.python.org)";
    }
    {
      key = "uv";
      matches = ["uv"];
      category = "Python";
      description = "Extremely fast Python package and project manager; replaces pip, venv, and pip-tools.";
      link = "[docs.astral.sh/uv](https://docs.astral.sh/uv/)";
    }
    {
      key = "jupyterlab (`jupyter-lab`)";
      matches = ["jupyterlab"];
      category = "Python";
      description = "Browser-based notebooks for interactive computing and data exploration.";
      link = "[jupyter.org](https://jupyter.org)";
    }
    {
      key = "ipython";
      matches = ["ipython"];
      category = "Python";
      description = "Enhanced interactive Python REPL with tab completion and magic commands.";
      link = "[ipython.org](https://ipython.org)";
    }
    {
      key = "ruff";
      matches = ["ruff"];
      category = "Python";
      description = "Extremely fast Python linter and formatter, written in Rust; replaces flake8/black/isort.";
      link = "[docs.astral.sh/ruff](https://docs.astral.sh/ruff/)";
    }
    {
      key = "ty";
      matches = ["ty"];
      category = "Python";
      description = "Extremely fast Python type checker from Astral (uv/ruff's maintainers); still pre-1.0.";
      link = "[github.com/astral-sh/ty](https://github.com/astral-sh/ty)";
    }
    {
      key = "pixi";
      matches = ["pixi"];
      category = "Python";
      description = "Cargo-style project/environment manager (conda-forge + PyPI packages, project-local lockfiles): chosen over conda/mamba for no base-environment management and reproducible lockfiles.";
      link = "[pixi.sh](https://pixi.sh)";
    }

    # ── AWS ────────────────────────────────────────────────────────────────
    {
      key = "awscli2";
      matches = ["awscli2"];
      category = "AWS";
      description = "Official AWS CLI v2: interact with all AWS services from the terminal.";
      link = "[docs.aws.amazon.com/cli](https://docs.aws.amazon.com/cli/latest/userguide/)";
    }
    {
      key = "aws-vault";
      matches = ["aws-vault"];
      category = "AWS";
      description = "Secure AWS credential storage and session management; wraps the CLI to avoid plaintext credentials.";
      link = "[github.com/99designs/aws-vault](https://github.com/99designs/aws-vault)";
    }
    {
      key = "s5cmd";
      matches = ["s5cmd"];
      category = "AWS";
      description = "High-performance S3 and local filesystem execution tool; parallel transfers far faster than the AWS CLI for bulk operations.";
      link = "[github.com/peak/s5cmd](https://github.com/peak/s5cmd)";
    }
    {
      key = "session-manager-plugin";
      matches = ["ssm-session-manager-plugin"];
      category = "AWS";
      description = "AWS CLI plugin enabling `aws ssm start-session`: shell access to EC2 instances and port forwarding without SSH/bastion hosts.";
      link = "[docs.aws.amazon.com/systems-manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)";
    }

    # ── Kubernetes ─────────────────────────────────────────────────────────
    {
      key = "kubectl";
      matches = ["kubectl"];
      category = "Kubernetes";
      description = "Kubernetes CLI: homelab k3s cluster ops. Kubeconfig lives at `~/.kube/config` (contains client certs, never committed, not Nix-managed).";
      link = "[kubernetes.io/docs/reference/kubectl](https://kubernetes.io/docs/reference/kubectl/)";
    }
    {
      key = "helm (`kubernetes-helm`)";
      matches = ["kubernetes-helm"];
      category = "Kubernetes";
      description = "Kubernetes package manager: install and manage chart releases.";
      link = "[helm.sh](https://helm.sh)";
    }
    {
      key = "helmfile";
      matches = ["helmfile"];
      category = "Kubernetes";
      description = "Declarative spec for deploying multiple Helm releases together.";
      link = "[github.com/helmfile/helmfile](https://github.com/helmfile/helmfile)";
    }

    # ── Secrets ────────────────────────────────────────────────────────────
    {
      key = "sops";
      matches = ["sops"];
      category = "Secrets";
      description = "Encrypts/decrypts secrets in files using age or PGP recipients, keeping ciphertext safe to commit.";
      link = "[github.com/getsops/sops](https://github.com/getsops/sops)";
    }
    {
      key = "age";
      matches = ["age"];
      category = "Secrets";
      description = "Simple, modern file encryption tool; the recipient/key mechanism sops uses here.";
      link = "[age-encryption.org](https://age-encryption.org)";
    }
    {
      key = "rbw";
      matches = ["rbw"];
      category = "Secrets";
      description = "Maintained Rust Bitwarden CLI (official `bitwarden-cli` is marked broken in the current nixpkgs pin); its agent caches unlock for scripting.";
      link = "[github.com/doy/rbw](https://github.com/doy/rbw)";
    }
    {
      key = "pinentry-tty";
      matches = ["pinentry-tty"];
      category = "Secrets";
      description = "Lets rbw prompt for the master password from the terminal (cross-platform; macOS has no pinentry by default).";
      link = "[gnupg.org/software/pinentry](https://gnupg.org/software/pinentry.html)";
    }

    # ── Shell Multiplexing ─────────────────────────────────────────────────
    {
      key = "tmux";
      matches = ["tmux"];
      category = "Shell Multiplexing";
      description = "Terminal multiplexer: persistent sessions, split panes, detach/reattach. Vi key bindings configured. On `*-server` profiles, tmux-resurrect and tmux-continuum are also installed, so long-lived server sessions survive a reboot: continuum wraps resurrect for automatic save and restore; neither works without the other.";
      link = "[github.com/tmux/tmux](https://github.com/tmux/tmux)";
    }

    # ── Firmware ───────────────────────────────────────────────────────────
    {
      key = "qmk";
      matches = ["qmk"];
      category = "Firmware";
      description = "QMK firmware CLI: compile and flash custom mechanical keyboard firmware (`qmk compile`, `qmk flash`). Dev profiles only; unavailable on x86_64-darwin (its `gcc-arm-embedded` dependency has no build for that platform).";
      link = "[qmk.fm](https://qmk.fm)";
    }

    # ── Environment Management ─────────────────────────────────────────────
    {
      key = "home-manager";
      matches = ["home-manager"];
      category = "Environment Management";
      description = "Manages the entire user environment declaratively via Nix. The tool that applies this config.";
      link = "[nix-community.github.io/home-manager](https://nix-community.github.io/home-manager/)";
    }
    {
      key = "just";
      matches = ["just"];
      category = "Environment Management";
      description = "Task runner / discoverability layer for this repo's own commands (`just --list` shows all of them).";
      link = "[github.com/casey/just](https://github.com/casey/just)";
    }
    {
      key = "direnv";
      matches = ["direnv"];
      category = "Environment Management";
      description = "Loads/unloads environment variables based on `.envrc` files when entering a directory. Integrates with Nix via `nix-direnv`.";
      link = "[direnv.net](https://direnv.net)";
    }

    # ── AI ─────────────────────────────────────────────────────────────────
    {
      key = "claude-code";
      matches = [];
      category = "AI";
      description = "Installed via its official native installer (curl-piped script), not npm or nixpkgs: ships multiple releases a week and self-updates in place, which nixpkgs packaging and Nix's rebuild cycle can't keep pace with.";
      link = "[claude.com/claude-code](https://claude.com/claude-code)";
    }

    # ── GUI (gui-linux / gui-darwin profiles only) ────────────────────────
    {
      key = "vscode";
      matches = ["vscode"];
      category = "GUI (gui-linux / gui-darwin profiles only)";
      description = "Code editor. Binary managed by Nix; extensions and settings via GitHub Settings Sync.";
      link = "[code.visualstudio.com](https://code.visualstudio.com)";
    }
    {
      key = "alacritty";
      matches = ["alacritty"];
      category = "GUI (gui-linux / gui-darwin profiles only)";
      description = "GPU-accelerated terminal emulator. Configured with Fira Code font and VS Code-style colors.";
      link = "[alacritty.org](https://alacritty.org)";
    }
    {
      key = "obsidian";
      matches = ["obsidian"];
      category = "GUI (gui-linux / gui-darwin profiles only)";
      description = "Markdown knowledge base. Notes repo is a separate clone.";
      link = "[obsidian.md](https://obsidian.md)";
    }
  ];

  # Documented but not visible via home.packages at all: no realized
  # package identity exists to match against, so the drift check can't
  # verify these automatically.
  nonPackageTools = [
    {
      key = "gitalias";
      category = "Git";
      description = "Large collection of git aliases (e.g. `git la` for log, `git undo`). Managed as a git submodule fork, wired in via `programs.git.includes`: not a Nix package.";
      link = "[github.com/GitAlias/gitalias](https://github.com/GitAlias/gitalias)";
    }
    {
      key = "kiro-cli";
      category = "AI";
      description = "AWS's agentic CLI. Installed via its official native installer, same rationale as claude-code: not in nixpkgs. Work profiles only.";
      link = "[kiro.dev/cli](https://kiro.dev/cli/)";
    }
  ];

  # Nix/home-manager plumbing that's expected to appear in every closure and
  # never needs a doc entry: implicitly injected by enabling programs (zsh
  # completion, bash, XDG mime defaults, HM's own manpage/session-var
  # generation), not something this repo's code chose to install.
  infraExclude = [
    "shared-mime-info"
    "dummy-xdg-mime-dirs1"
    "dummy-xdg-mime-dirs2"
    "hm-session-vars.fish"
    "hm-session-vars.sh"
    "home-configuration-reference-manpage"
    "man-db"
    "nix-zsh-completions"
  ];
}
