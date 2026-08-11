{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Kubernetes: homelab k3s cluster ops; kubeconfig lives at
    # ~/.kube/config (contains client certs: never committed, not Nix-managed)
    kubectl
    kubernetes-helm
    helmfile
  ];

  # helm-diff plugin for `helmfile diff`, pinned to the same nixpkgs revision
  # as kubernetes-helm above. Helm's plugin directory differs by platform:
  # `helm env` reports ~/Library/helm/plugins on Darwin, XDG_DATA_HOME/helm/plugins on Linux.
  home.file = {
    "${
      if pkgs.stdenv.isDarwin then
        "Library/helm/plugins/helm-diff"
      else
        ".local/share/helm/plugins/helm-diff"
    }".source =
      "${pkgs.kubernetes-helmPlugins.helm-diff}/helm-diff";
  };
}
