{pkgs, ...}: {
  home.packages = with pkgs; [
    # Kubernetes — homelab k3s cluster ops; kubeconfig lives at
    # ~/.kube/config (contains client certs — never committed, not Nix-managed)
    kubectl
    kubernetes-helm
    helmfile
  ];
}
