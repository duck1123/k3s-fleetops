{ config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } {
  name = "cert-manager";

  # https://artifacthub.io/packages/helm/cert-manager/cert-manager
  chart = lib.helm.downloadHelmChart {
    repo = "https://charts.jetstack.io";
    chart = "cert-manager";
    version = "v1.17.1";
    chartHash = "sha256-CUKd2R911uTfr461MrVcefnfOgzOr96wk+guoIBHH0c=";
  };

  defaultValues = cfg: { crds.enabled = true; };
}
