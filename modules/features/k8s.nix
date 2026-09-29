{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Kubernetes: homelab k3s cluster ops; kubeconfig lives at
    # ~/.kube/config (contains client certs: never committed, not Nix-managed)
    kubectl
    kubernetes-helm
    helmfile

    # Home Assistant runs on that cluster, and parts of its API are websocket
    # ONLY with no REST equivalent: the entity and device registries, Lovelace
    # resource management, and reading persistent notifications (which stopped
    # being entities, so /api/states cannot see them). Without a websocket
    # client those operations can only be done by hand in the UI, or by editing
    # HA's .storage with the pod scaled to zero.
    websocat
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
