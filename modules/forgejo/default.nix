{ charts, config, lib, pkgs, ... }:
let
  cfg = config.services.forgejo;

  chart = lib.helmChart {
    inherit pkgs;
    chartTgz = ../../charts/forgejo-11.0.3.tgz;
    chartName = "forgejo";
  };

  defaultNamespace = "forgejo";
  domain = "git.dev.kronkltd.net";

  # https://artifacthub.io/packages/helm/forgejo-helm/forgejo
  defaultValues = {
    gitea = {
      additionalConfigFromEnvs = [{
        name = "FORGEJO__DATABASE__PASSWD";
        valueFrom.secretKeyRef = {
          key = "adminPassword";
          name = "postgresql-password";
        };
      }];

      admin.existingSecret = "forgejo-admin-password";

      config.database = {
        DB_TYPE = "postgres";
        HOST = "postgresql.postgresql:5432";
        USER = "postgres";
        NAME = "gitea";
        SCHEMA = "public";
      };

      metrics.enabled = true;
    };

    ingress = {
      annotations = {
        "cert-manager.io/cluster-issuer" = "letsencrypt-prod";
        "ingress.kubernetes.io/force-ssl-redirect" = "true";
      };
      className = "traefik";
      enabled = false;
      hosts = [{
        host = domain;
        paths = [{
          path = "/";
          pathType = "ImplementationSpecific";
        }];
      }];
      tls = [{
        hosts = [ domain ];
        secretName = "forgejo-tls";
      }];
    };

    postgresql.enabled = false;
    postgresql-ha.enabled = false;
    redis.enabled = false;
    redis-cluster.enabled = false;
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.forgejo = {
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
    applications.forgejo = {
      inherit namespace;
      createNamespace = true;
      helm.releases.forgejo = { inherit chart values; };
    };
  };
}
