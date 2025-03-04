{ charts, config, lib, ... }:
let
  cfg = config.services.minio;

  chart = lib.helm.downloadHelmChart {
    repo = "https://charts.bitnami.com/bitnami";
    chart = "minio";
    version = "14.8.5";
    chartHash = "sha256-zP40G0NweolTpH/Fnq9nOe486n39MqJBqQ45GwJEc1I=";
  };

  defaultNamespace = "minio";
  domain = "minio.dev.kronkltd.net";

  clusterIssuer = "letsencrypt-prod";

  defaultValues = {
    apiIngress = {
      enabled = true;
      ingressClassName = "traefik";
      hostname = "minio-api.dev.kronkltd.net";
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
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.minio = {
    enable = mkEnableOption "Enable application";
    namespace = mkOption {
      description = mdDoc "The namespace to install into";
      type = types.str;
      default = defaultNamespace;
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
      helm.releases.minio = { inherit chart values; };
    };
  };
}
