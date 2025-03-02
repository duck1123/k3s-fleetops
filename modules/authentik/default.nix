{ charts, config, lib, ... }:
let
  cfg = config.services.authentik;

  chartConfig = {
    repo = "https://charts.goauthentik.io/";
    chart = "authentik";
    version = "2024.10.4";
    chartHash = "sha256-wMEFXWJDI8pHqKN7jrQ4K8+s1c2kv6iN6QxiLPZ1Ytk=";
  };

  defaultNamespace = "authentik";
  domain = "authentik.dev.kronkltd.net";

  defaultValues = {
    authentik.error_reporting.enabled = true;
    global.env = [
      {
        name = "AUTHENTIK_SECRET_KEY";
        valueFrom.secretKeyRef = {
          name = "authentik-secret-key";
          key = "authentik-secret-key";
        };
      }
      {
        name = "AUTHENTIK_POSTGRESQL__PASSWORD";
        valueFrom.secretKeyRef = {
          name = "authentik-postgres-auth";
          key = "password";
        };
      }
    ];
    postgresql = {
      enabled = true;
      auth.existingSecret = "authentik-postgres-auth";
    };

    redis.enabled = true;

    server.ingress = {
      enabled = true;
      annotations = {
        "cert-manager.io/cluster-issuer" = "letsencrypt-prod";
        "ingress.kubernetes.io/force-ssl-redirect" = "true";
        "ingress.kubernetes.io/proxy-body-size" = "0";
        "ingress.kubernetes.io/ssl-redirect" = "true";
      };
      ingressClassName = "traefik";
      hosts = [ domain ];
      tls = [{
        secretName = "authentik-tls";
        hosts = [ domain ];
      }];
      https = false;
    };
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.authentik = {
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
    applications.authentik = let chart = helm.downloadHelmChart chartConfig;
    in {
      inherit namespace;
      createNamespace = true;
      helm.releases.authentik = { inherit chart values; };
    };
  };
}
