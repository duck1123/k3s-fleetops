{ ageRecipients, config, lib, pkgs, ... }:
with lib;
let password-secret = "mariadb-password";
in mkArgoApp { inherit config lib; } rec {
  name = "mariadb";

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
    };

    storageClass = mkOption {
      description = mdDoc "The storage class to use for persistence";
      type = types.str;
      default = "local-path";
    };
  };

  extraResources = cfg: {
    deployments.mariadb = {
      spec = {
        replicas = 1;
        selector.matchLabels.app = name;
        template = {
          metadata.labels.app = name;
          spec = {
            containers = [{
              name = name;
              image = "mariadb:11.0";
              ports = [{ containerPort = 3306; }];
              env = [
                {
                  name = "MYSQL_ROOT_PASSWORD";
                  valueFrom = {
                    secretKeyRef = {
                      name = password-secret;
                      key = "rootPassword";
                    };
                  };
                }
                {
                  name = "MYSQL_USER";
                  valueFrom = {
                    secretKeyRef = {
                      name = password-secret;
                      key = "username";
                    };
                  };
                }
                {
                  name = "MYSQL_PASSWORD";
                  valueFrom = {
                    secretKeyRef = {
                      name = password-secret;
                      key = "password";
                    };
                  };
                }
                {
                  name = "MYSQL_DATABASE";
                  valueFrom = {
                    secretKeyRef = {
                      name = password-secret;
                      key = "database";
                    };
                  };
                }
              ];
              volumeMounts = [{
                name = "${name}-storage";
                mountPath = "/var/lib/mysql";
              }];
            }];
            volumes = [{
              name = "${name}-storage";
              persistentVolumeClaim.claimName = "${name}-pvc";
            }];
          };
        };
      };
    };

    # Persistent Volume Claim
    persistentVolumeClaims.mariadb-pvc = {
      apiVersion = "v1";
      kind = "PersistentVolumeClaim";
      metadata = {
        name = "${name}-pvc";
        namespace = cfg.namespace;
      };
      spec = {
        accessModes = [ "ReadWriteOnce" ];
        resources = { requests = { storage = "8Gi"; }; };
        storageClassName = cfg.storageClass;
      };
    };

    # Service
    services.mariadb = {
      spec = {
        selector = { app = name; };
        ports = [{
          port = 3306;
          targetPort = 3306;
        }];
        type = "ClusterIP";
      };
    };

    sopsSecrets.${password-secret} = lib.createSecret {
      inherit ageRecipients lib pkgs;
      inherit (cfg) namespace;
      secretName = password-secret;
      values = with cfg.auth; {
        inherit rootPassword username password database;
      };
    };
  };
}
