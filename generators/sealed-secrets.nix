{
  inputs,
  pkgs,
  system,
  ...
}:
let
  inherit (inputs.nixidy.packages.${system}.generators) fromCRD;
in
fromCRD {
  name = "sealed-secrets";
  src = pkgs.fetchFromGitHub {
    owner = "bitnami-labs";
    repo = "sealed-secrets";
    rev = "v0.28.0";
    hash = "sha256-YyiYryNLSY8XnrA+3AWeQR2p55YNHFfp/sWCevATdZ0=";
  };
  crds = [ "helm/sealed-secrets/crds/bitnami.com_sealedsecrets.yaml" ];
}
