{ config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } {
  name = "argo-events";

  # https://artifacthub.io/packages/helm/argo/argo-events
  chart = lib.helm.downloadHelmChart {
    repo = "https://argoproj.github.io/argo-helm";
    chart = "argo-events";
    version = "2.4.14";
    chartHash = "sha256-gLZOCMLYd9lSQfOQKqgYVscsDcsOTc1v25FvY0P95W4=";
  };

  uses-ingress = true;

  defaultValues = cfg: { metrics.enabled = true; };
}
