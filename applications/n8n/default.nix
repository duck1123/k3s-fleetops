{ config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } rec {
  name = "n8n";

  # https://artifacthub.io/packages/helm/community-charts/n8n
  chart = lib.helm.downloadHelmChart {
    repo = "https://community-charts.github.io/helm-charts";
    chart = "n8n";
    version = "1.15.10";
    chartHash = "sha256-jL44FQfoXsmMCpF9ec3zTRXxTfqweFl0Nr55Z3kvvEo=";
  };

  uses-ingress = true;

  defaultValues = cfg: {
    ingress = with cfg.ingress; {
      enabled = true;
      className = ingressClassName;

      hosts = [{
        host = domain;
        paths = [{
          path = "/";
          pathType = "Prefix";
        }];
      }];

      tls = [{
        secretName = "n8n-tls";
        hosts = [ domain ];
      }];
    };
  };
}
