{ charts, config, lib, ... }:
let
  app-name = "minio";
  cfg = config.services.${app-name};

  # https://artifacthub.io/packages/helm/bitnami/minio
  chart = lib.helm.downloadHelmChart {
    repo = "https://charts.bitnami.com/bitnami";
    chart = "minio";
    version = "16.0.7";
    chartHash = "sha256-+srPCRCyltF2gKM8ourGqSBjgbt+05bYJBoB6zuXPaU=";
  };

  defaultApiDomain = "api.minio.localhost";
  defaultDomain = "minio.localhost";

  # clusterIssuer = "letsencrypt-prod";
  clusterIssuer = "tailscale";
  ingressClassName = "tailscale";

  defaultValues = {
    apiIngress = {
      inherit ingressClassName;
      enabled = true;
      hostname = cfg.api-domain;
      annotations = {
        "cert-manager.io/cluster-issuer" = clusterIssuer;
        "ingress.kubernetes.io/force-ssl-redirect" = "true";
        "ingress.kubernetes.io/proxy-body-size" = "0";
        "ingress.kubernetes.io/ssl-redirect" = "true";
      };
      tls = true;
    };

    auth = {
      existingSecret = "minio-password";
      rootUserSecretKey = "user";
    };

    ingress = {
      inherit ingressClassName;
      enabled = true;
      hostname = cfg.domain;
      annotations = {
        "cert-manager.io/cluster-issuer" = clusterIssuer;
        "ingress.kubernetes.io/force-ssl-redirect" = "true";
        "ingress.kubernetes.io/proxy-body-size" = "0";
        "ingress.kubernetes.io/ssl-redirect" = "true";
      };
      tls = cfg.tls.enable;
    };
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.minio = {
    api-domain = mkOption {
      description = mdDoc "The ingress domain for the API";
      type = types.str;
      default = defaultApiDomain;
    };

    enable = mkEnableOption "Enable application";

    namespace = mkOption {
      description = mdDoc "The namespace to install into";
      type = types.str;
      default = app-name;
    };

    domain = mkOption {
      description = mdDoc "The ingress domain";
      type = types.str;
      default = defaultDomain;
    };

    tls = {
      enable = mkEnableOption "Enable application";
    };

    values = mkOption {
      description = "All the values";
      type = types.attrsOf types.anything;
      default = { };
    };
  };

  config = mkIf cfg.enable {
    applications.minio = {
      inherit (cfg) namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.minio = { inherit chart values; };
    };
  };
}
