{ config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } {
  name = "minio";
  chart = helm.downloadHelmChart {
    repo = "https://charts.bitnami.com/bitnami";
    chart = "minio";
    version = "16.0.7";
    chartHash = "sha256-+srPCRCyltF2gKM8ourGqSBjgbt+05bYJBoB6zuXPaU=";
  };
  uses-ingress = true;
  extraOptions = {
    ingress.api-domain = mkOption {
      description = mdDoc "The ingress domain for the API";
      type = types.str;
      default = defaultApiDomain;
    };
  };
  defaultValues = (cfg:
    let
      inherit (cfg.ingress)
        api-domain clusterIssuer domain ingressClassName tls;
    in {
      apiIngress = {
        inherit ingressClassName;
        enabled = true;
        hostname = api-domain;
        annotations = {
          "cert-manager.io/cluster-issuer" = clusterIssuer;
          "ingress.kubernetes.io/force-ssl-redirect" = "true";
          "ingress.kubernetes.io/proxy-body-size" = "0";
          "ingress.kubernetes.io/ssl-redirect" = "true";
        };
        tls = tls.enable;
      };

      auth = {
        existingSecret = "minio-password";
        rootUserSecretKey = "user";
      };

      ingress = {
        inherit ingressClassName;
        enabled = true;
        hostname = domain;
        annotations = {
          "cert-manager.io/cluster-issuer" = clusterIssuer;
          "ingress.kubernetes.io/force-ssl-redirect" = "true";
          "ingress.kubernetes.io/proxy-body-size" = "0";
          "ingress.kubernetes.io/ssl-redirect" = "true";
        };
        tls = tls.enable;
      };
    });
}
