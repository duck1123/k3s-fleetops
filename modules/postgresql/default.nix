{ ageRecipients, config, lib, pkgs, ... }:
with lib;
let password-secret = "postgresql-password";
in mkArgoApp { inherit config lib; } {
  name = "postgresql";

  # https://artifacthub.io/packages/helm/bitnami/postgresql
  chart = lib.helmChart {
    inherit pkgs;
    chartTgz = ../../chart-archives/postgresql-16.7.27.tgz;
    chartName = "postgresql";
  };

  extraOptions = {
    auth = {
      adminPassword = mkOption {
        description = mdDoc "The admin password";
        type = types.str;
        default = "CHANGEME";
      };

      adminUsername = mkOption {
        description = mdDoc "The admin username";
        type = types.str;
        default = "admin";
      };

      replicationPassword = mkOption {
        description = mdDoc "The replication password";
        type = types.str;
        default = "CHANGEME";
      };

      userPassword = mkOption {
        description = mdDoc "The user password";
        type = types.str;
        default = "postgres";
      };
    };

    storageClass = mkOption {
      description = mdDoc "The storage class to use for persistence";
      type = types.str;
      default = "local-path";
    };
  };

  defaultValues = cfg: {
    global = {
      defaultStorageClass = cfg.storageClass;

      postgresql.auth = {
        existingSecret = password-secret;
        secretKeys = {
          adminPasswordKey = "adminPassword";
          userPasswordKey = "userPassword";
          replicationPasswordKey = "replicationPassword";
        };
      };

      security.allowInsecureImages = true;
    };

    image = {
      repository = "chainguard/postgres";
      tag = "latest";
    };
  };

  extraResources = cfg: {
    sopsSecrets.${password-secret} = lib.createSecret {
      inherit ageRecipients lib pkgs;
      inherit (cfg) namespace;
      secretName = password-secret;
      values = with cfg; {
        inherit (auth)
          adminPassword adminUsername replicationPassword userPassword;
      };
    };
  };
}
