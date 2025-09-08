{ config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } {
  name = "marquez";

  # https://artifacthub.io/packages/helm/ilum/ilum-marquez
  chart = lib.helm.downloadHelmChart {
    repo = "https://charts.ilum.cloud";
    chart = "ilum-marquez";
    version = "0.42.0";
    chartHash = "sha256-9Z3f8rvSkisrY9b466MiQYgqeHCY5AvjKq7Q8aJ3OKg=";
  };

  uses-ingress = true;

  extraOptions = {
  };

  defaultValues = cfg: {
    ingress = {
      enabled = false;
      hosts = [ cfg.ingress.domain ];
    };

    marquez = {
      hostname = cfg.ingress.domain;
    };

    web = {
      enabled = true;
    };
  };

  extraResources = cfg: {
    ingresses.imum-marquez-ingress.spec = {
      ingressClassName = "traefik";
      rules = [
        {
          host = cfg.ingress.domain;
          http = {
            paths = [
              {
                path = "/api/";
                pathType = "Prefix";
                backend.service = {
                  name = "imum-marquez-web";
                  port.name = "http";
                };
              }
            ];
          };
        }
      ];

      tls = [
        {
          hosts = [ cfg.ingress.domain ];
          secretName = "marquez-tls";
        }
      ];
    };
  };
}
