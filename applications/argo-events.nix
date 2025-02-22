{ lib, ... }: {
  applications.argo-events = {
    namespace = "argo-events";
    createNamespace = true;

    helm.releases.argo-events = {
      chart = lib.helm.downloadHelmChart {
        repo = "https://argoproj.github.io/argo-helm";
        chart = "argo-events";
        version = "2.4.9";
        chartHash = "sha256-tndmg6tUHYnyWbiWVvxSI9tNQwjYBzWwNa8OXRSxYAQ=";
      };

      values.metrics.enabled = true;
    };
  };
}
