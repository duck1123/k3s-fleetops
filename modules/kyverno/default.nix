{ config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } {
  name = "kyverno";

  chart = lib.helm.downloadHelmChart {
    repo = "https://kyverno.github.io/kyverno/";
    chart = "kyverno";
    version = "3.4.0-alpha.1";
    chartHash = "sha256-rYlJrh8h1oiq7zRxLqEuFW2Kxst90iFAyEDUJes84x0=";
  };

  uses-ingress = true;

  extraOptions = {
    # codeserver.ingress = {
    #   clusterIssuer = mkOption {
    #     description = mdDoc "The cookie secret";
    #     type = types.str;
    #     default = "CHANGEME";
    #   };
    #   domain = mkOption {
    #     description = mdDoc "The cookie secret";
    #     type = types.str;
    #     default = "CHANGEME";
    #   };
    #   ingressClassName = mkOption {
    #     description = mdDoc "The cookie secret";
    #     type = types.str;
    #     default = "CHANGEME";
    #   };
    # };

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
