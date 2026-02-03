{ config, lib, pkgs, ... }:
with lib;
mkArgoApp { inherit config lib; } {
  name = "forgejo";

  # https://artifacthub.io/packages/helm/forgejo-helm/forgejo
  chart = lib.helmChart {
    inherit pkgs;
    chartTgz = ../../chart-archives/forgejo-12.5.2.tgz;
    chartName = "forgejo";
  };

  uses-ingress = true;

  extraOptions = {
    admin = {
      password = mkOption {
        description = mdDoc "The admin password";
        type = types.str;
        default = "CHANGEME";
      };

      username = mkOption {
        description = mdDoc "The admin username";
        type = types.str;
        default = "admin";
      };
    };

    postgresql = {
      adminPassword = mkOption {
        description = mdDoc "The admin password";
        type = types.str;
        default = "CHANGEME";
      };

      adminUsername = mkOption {
        description = mdDoc "The admin username";
        type = types.str;
        default = "postgres";
      };

      replicationPassword = mkOption {
        description = mdDoc "The replication password";
        type = types.str;
        default = "CHANGEME";
      };

      userPassword = mkOption {
        description = mdDoc "The user password";
        type = types.str;
        default = "CHANGEME";
      };
    };

    storageClass = mkOption {
      description = mdDoc "The storage class to use for persistence";
      type = types.str;
      default = "local-path";
    };
  };

  defaultValues = cfg: {
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

    ingress = with cfg.ingress; {
      annotations = {
        "cert-manager.io/cluster-issuer" = clusterIssuer;
        "ingress.kubernetes.io/force-ssl-redirect" = "true";
      };
      className = ingressClassName;
      enabled = true;
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

    persistence = { inherit (cfg) storageClass; };
    postgresql.enabled = false;
    postgresql-ha.enabled = false;
    redis.enabled = false;
    redis-cluster.enabled = false;
  };

  extraResources = cfg: {
    sopsSecrets = {
      forgejo-admin-password = lib.createSecret {
        inherit ageRecipients lib pkgs;
        inherit (cfg) namespace;
        secretName = "forgejo-admin-password";
        values = { inherit (cfg.admin) password username; };
      };

      postgresql-password = lib.createSecret {
        inherit ageRecipients lib pkgs;
        inherit (cfg) namespace;
        secretName = "postgresql-password";
        values = {
          inherit (cfg.postgresql)
            adminPassword adminUsername replicationPassword userPassword;
        };
      };
    };
  };
}
