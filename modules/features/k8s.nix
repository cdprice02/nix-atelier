{pkgs, ...}: {
  home.packages = with pkgs; [
    # Kubernetes — homelab cluster ops (queen.local k3s); kubeconfig lives at
    # ~/.kube/config (contains client certs — never committed, not Nix-managed)
    kubectl
    kubernetes-helm
    helmfile
  ];
}
