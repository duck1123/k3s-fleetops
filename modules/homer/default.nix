{ config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } {
  name = "homer";

  # https://artifacthub.io/packages/helm/gabe565/homer
  chart = helm.downloadHelmChart {
    repo = "https://charts.gabe565.com";
    chart = "homer";
    version = "0.13.0";
    chartHash = "sha256-z6o5LHUYqm7Jd5gsIs+J3Z48Frbj8F1ZnEZw4mHIeQA=";
  };

  uses-ingress = true;

  extraOptions = {
    codeserver.ingress = {
      clusterIssuer = mkOption {
        description = mdDoc "The cookie secret";
        type = types.str;
        default = "CHANGEME";
      };
      domain = mkOption {
        description = mdDoc "The cookie secret";
        type = types.str;
        default = "CHANGEME";
      };
      ingressClassName = mkOption {
        description = mdDoc "The cookie secret";
        type = types.str;
        default = "CHANGEME";
      };
    };

  };

  defaultValues = cfg: {
    ingress = with cfg.ingress; {
      main = {
        enabled = true;
        hosts = [{
          host = domain;
          paths = [{ path = "/"; }];
        }];
        tls = [{
          secretName = tls.secretName;
          hosts = [ domain ];
        }];
      };

      addons.codeserver = with cfg.codeserver.ingress; {
        enabled = true;
        ingress = {
          enabled = true;
          hosts = [{
            host = domain;
            paths = [{ path = "/"; }];
          }];
          tls = [{
            secretName = "codeserver-tls";
            hosts = [ domain ];
          }];
        };
      };
    };
  };
}
