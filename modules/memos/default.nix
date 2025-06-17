{ config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } rec {
  name = "memos";

  # https://artifacthub.io/packages/helm/gabe565/memos
  chart = lib.helm.downloadHelmChart {
    repo = "https://charts.gabe565.com";
    chart = "memos";
    version = "0.15.1";
    chartHash = "sha256-k9UU0fLgFgn/aogTD+PMxcQOnZ9g47vFXeyhnf2hqbQ=";
  };

  uses-ingress = true;

  defaultValues = cfg: {
    ingress.main = with cfg.ingress; {
      enabled = false;
      hosts = [{
        host = domain;
        paths = [{ path = "/"; }];
      }];
      tls = [{
        secretName = "memo-tls";
        hosts = [ domain ];
      }];
    };
    persistence.data.enabled = false;
    postgresql = {
      enabled = true;
      primary.persistence.enabled = false;
    };
  };

  extraResources = cfg:
    with cfg; {
      ingresses = with cfg.ingress; {
        memos.spec = {
          inherit (cfg.ingress) ingressClassName;
          rules = [{
            host = domain;
            http = {
              paths = [{
                path = "/";
                pathType = "ImplementationSpecific";
                backend.service = {
                  inherit name;
                  port.name = "http";
                };
              }];
            };
          }];
          tls = [{
            hosts = [ domain ];
            secretName = tls.secretName;
          }];
        };
      };
    };
}
