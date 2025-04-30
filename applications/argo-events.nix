{ ... }:
{
  flake.nixidyApps.argo-events =
    {
      config,
      lib,
      self,
      ...
    }:
    self.lib.mkArgoApp { inherit config lib; } {
      name = "argo-events";

      # https://artifacthub.io/packages/helm/argo/argo-events
      chart = lib.helm.downloadHelmChart {
        repo = "https://argoproj.github.io/argo-helm";
        chart = "argo-events";
        version = "2.4.21";
        chartHash = "sha256-I2seJPvPXti08DSnWFbjH9wj4ysx8zYLSN4D8CU4aHQ=";
      };

      defaultValues = cfg: { metrics.enabled = true; };
    };
}
