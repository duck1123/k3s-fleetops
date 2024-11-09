{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  buildInputs = with pkgs; [
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
