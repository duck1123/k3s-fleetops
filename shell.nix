{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  buildInputs = with pkgs; [
    argo
    argocd
    babashka
    clojure
    docker
    gum
    jet
    keepassxc
    kubectl
    kubernetes-helm
    kubeseal
    openssl
  ];
}
