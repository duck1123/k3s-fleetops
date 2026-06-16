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
    owner = "bitnami";
    repo = "sealed-secrets";
    rev = "v0.27.0";
    hash = "sha256-Ja+z+QmdU37RC9WIczlmzJWN6enhks3jDJLQMV+kfCY=";
  };
  crds = [ "helm/sealed-secrets/crds/bitnami.com_sealedsecrets.yaml" ];
}
