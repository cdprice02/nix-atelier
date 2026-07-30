{pkgs, ...}: {
  home.packages = with pkgs; [
    # Python ecosystem
    python3
    uv
    python3Packages.jupyterlab
    python3Packages.ipython
  ];
}
