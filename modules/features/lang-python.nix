{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Python ecosystem
    python3
    uv
    python3Packages.jupyterlab
    python3Packages.ipython
    ruff
    ty
    # Edit .ipynb notebooks as plain `# %%` scripts; Neovim's jupytext.nvim
    # converts through it on open and save.
    python3Packages.jupytext
    # Project/environment manager independent of Python's own tooling
    # (uv handles Python specifically): chosen over conda/mamba: no base
    # environment to manage, Cargo-style project-local lockfiles.
    pixi
  ];
}
