{ config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } {
  name = "cloudbeaver";

  # https://artifacthub.io/packages/helm/homeenterpriseinc/cloudbeaver
  chart = helm.downloadHelmChart {
    repo = "https://homeenterpriseinc.github.io/helm-charts/";
    chart = "cloudbeaver";
    version = "0.6.0";
    chartHash = "sha256-+UuoshmHyNzVlWqpKP+DlWtgALnerkLdhx1ldQSorLk=";
  };

  uses-ingress = true;

  # extraOptions = {
  #   codeserver = {
  #     clusterIssuer  = mkOption {
  #       description = mdDoc "The cookie secret";
  #       type = str;
  #       default = "CHANGEME";
  #     };
  #     domain = mkOption {
  #       description = mdDoc "The cookie secret";
  #       type = str;
  #       default = "CHANGEME";
  #     };
  #     ingressClassName = mkOption {
  #       description = mdDoc "The cookie secret";
  #       type = str;
  #       default = "CHANGEME";
  #     };
  #   };
  # };

  defaultValues = cfg: {
    image.tag = "24.2.5";
    ingress = with cfg.ingress; {
      annotations = {
        "cert-manager.io/cluster-issuer" = clusterIssuer;
        "ingress.kubernetes.io/force-ssl-redirect" = "true";
      };
      enabled = false;
      hosts = [{
        host = domain;
        paths = [{
          path = "/";
          pathType = "ImplementationSpecific";
        }];
      }];
      tls = [ ];
    };
    persistence.enabled = false;
  };

  extraResources = cfg: {
    ingresses.cloudbeaver-ingress = with cfg.ingress; {
      metadata.annotations = {
        # "cert-manager.io/cluster-issuer" = cfg.clusterIssuer;
        # "ingress.kubernetes.io/force-ssl-redirect" = "true";
        # "ingress.kubernetes.io/proxy-body-size" = "0";
        # "ingress.kubernetes.io/ssl-redirect" = "true";
        # "kubernetes.io/ingress.class" = "traefik";
      };
      spec = {
        inherit ingressClassName;
        rules = [{
          host = domain;
          http.paths = [{
            backend.service = {
              name = "cloudbeaver-svc";
              port.name = "http";
            };
            path = "/";
            pathType = "ImplementationSpecific";
          }];
        }];
        tls = [{
          inherit (tls) secretName;
          hosts = [ domain ];
        }];
      };
    };
  };
}
