{ config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } {
  name = "cert-manager";

  # https://artifacthub.io/packages/helm/cert-manager/cert-manager
  chart = lib.helm.downloadHelmChart {
    repo = "https://charts.jetstack.io";
    chart = "cert-manager";
    version = "v1.17.2";
    chartHash = "sha256-8d/BPet3MNGd8n0r5F1HEW4Rgb/UfdtwqSFuUZTyKl4=";
  };

  defaultValues = cfg: { crds.enabled = true; };
}
