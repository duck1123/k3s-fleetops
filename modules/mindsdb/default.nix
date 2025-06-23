{ config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } {
  name = "mindsdb";

  # https://artifacthub.io/packages/helm/kronkltd/mindsdb
  chart = helm.downloadHelmChart {
    repo = "https://chart.kronkltd.net/";
    chart = "mindsdb";
    version = "0.1.0";
    chartHash = "sha256-BExMwx1a2ovklEratuFXVujdmPgLypQJKcNyh+630Ig=";
  };

  uses-ingress = true;

  defaultValues = cfg: {
    ingress = let inherit (cfg.ingress) domain tls;
    in {
      enabled = true;
      hosts = [{
        host = domain;
        paths = [{
          path = "/";
          pathType = "ImplementationSpecific";
        }];
      }];
      tls = mkIf tls.enable [{
        secretName = tls.secretName;
        hosts = [ domain ];
      }];
    };
  };
}
