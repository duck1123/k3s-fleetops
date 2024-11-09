{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  buildInputs = with pkgs; [
    argocd
    babashka
    clojure
    docker
    jet
    keepassxc
    kubectl
    kubernetes-helm
    kubeseal
  ];
}
