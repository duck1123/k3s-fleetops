{ charts, config, lib, ... }:
let
  cfg = config.services.minio;

  chart = lib.helm.downloadHelmChart {
    repo = "https://charts.bitnami.com/bitnami";
    chart = "minio";
    version = "14.8.5";
    chartHash = "sha256-zP40G0NweolTpH/Fnq9nOe486n39MqJBqQ45GwJEc1I=";
  };

  defaultApiDomain = "minio-api.localhost";
  defaultDomain = "minio.localhost";
  defaultNamespace = "minio";

  clusterIssuer = "letsencrypt-prod";

  defaultValues = {
    apiIngress = {
      enabled = true;
      ingressClassName = "traefik";
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
      enabled = true;
      ingressClassName = "traefik";
      hostname = cfg.domain;
      annotations = {
        "cert-manager.io/cluster-issuer" = "letsencrypt-prod";
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
      default = defaultNamespace;
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
      inherit namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.minio = { inherit chart values; };
    };
  };
}
