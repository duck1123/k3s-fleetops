{ ageRecipients, config, lib, pkgs, ... }:
with lib;
let password-secret = "mariadb-password";
in mkArgoApp { inherit config lib; } {
  name = "mariadb";

  # https://artifacthub.io/packages/helm/bitnami/mariadb
  chart = lib.helm.downloadHelmChart {
    repo = "https://charts.bitnami.com/bitnami";
    chart = "mariadb";
    version = "24.0.2";
    chartHash = "sha256-JAoRQaBNPl5feMOBFHsCfrCgc3UoyKAIs+uo+H2IZio=";
  };

  extraOptions = {
    auth = {
      rootPassword = mkOption {
        description = mdDoc "The root password";
        type = types.str;
        default = "CHANGEME";
      };

      username = mkOption {
        description = mdDoc "The username";
        type = types.str;
        default = "mariadb";
      };

      password = mkOption {
        description = mdDoc "The user password";
        type = types.str;
        default = "CHANGEME";
      };

      database = mkOption {
        description = mdDoc "The database name";
        type = types.str;
        default = "mydb";
      };

      replicationPassword = mkOption {
        description = mdDoc "The replication password";
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
    auth = {
      existingSecret = password-secret;
      username = cfg.auth.username;
      database = cfg.auth.database;
    };

    primary.persistence.storageClass = cfg.storageClass;
  };

  extraResources = cfg: {
    sopsSecrets.${password-secret} = lib.createSecret {
      inherit ageRecipients lib pkgs;
      inherit (cfg) namespace;
      secretName = password-secret;
      values = {
        "mariadb-root-password" = cfg.auth.rootPassword;
        "mariadb-password" = cfg.auth.password;
        "mariadb-replication-password" = cfg.auth.replicationPassword;
        username = cfg.auth.username;
        database = cfg.auth.database;
      };
    };
  };
}
