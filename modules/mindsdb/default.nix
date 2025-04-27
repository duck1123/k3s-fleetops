{ config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } {
  name = "mindsdb";
  chart = helm.downloadHelmChart {
    repo = "https://chart.kronkltd.net/";
    chart = "mindsdb";
    version = "0.1.0";
    chartHash = "sha256-BExMwx1a2ovklEratuFXVujdmPgLypQJKcNyh+630Ig=";
  };
  uses-ingress = true;
  defaultValues = (cfg: {
    ingress = let inherit (cfg.ingress) domain tls secretName;
    in {
      enabled = true;
      hosts = [{
        host = domain;
        paths = [{
          path = "/";
          pathType = "ImplementationSpecific";
        }];
      }];
      tls = mkIf tls.enabled [{
        secretName = secretName;
        hosts = [ domain ];
      }];
    };
  });
}
