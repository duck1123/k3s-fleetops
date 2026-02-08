{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  password-secret = "mariadb-password";
in
mkArgoApp { inherit config lib; } rec {
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

    extraDatabases = mkOption {
      description = mdDoc "Additional databases to create (list of {name, username, password})";
      type = types.listOf (
        types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              description = mdDoc "Database name";
            };
            username = mkOption {
              type = types.str;
              description = mdDoc "Database username";
            };
            password = mkOption {
              type = types.str;
              description = mdDoc "Database password";
            };
          };
        }
      );
      default = [ ];
    };

    storageClass = mkOption {
      description = mdDoc "The storage class to use for persistence";
      type = types.str;
      default = "local-path";
    };

    backup = {
      enable = mkOption {
        description = mdDoc "Enable automated database backups";
        type = types.bool;
        default = true;
      };

      schedule = mkOption {
        description = mdDoc "Cron schedule for backups (default: daily at 2 AM)";
        type = types.str;
        default = "0 2 * * *";
      };

      retentionDays = mkOption {
        description = mdDoc "Number of days to retain backups";
        type = types.int;
        default = 30;
      };

      storageSize = mkOption {
        description = mdDoc "Storage size for backup PVC";
        type = types.str;
        default = "50Gi";
      };
    };
  };

  defaultValues = cfg: {
    auth = {
      existingSecret = password-secret;
      username = cfg.auth.username;
      database = cfg.auth.database;
    };

    # Add initdb scripts for extra databases
    initdbScripts = lib.listToAttrs (
      map (db: {
        name = "init-${db.name}.sql";
        value = ''
          CREATE DATABASE IF NOT EXISTS `${db.name}`;
          CREATE USER IF NOT EXISTS '${db.username}'@'%' IDENTIFIED BY '${db.password}';
          GRANT ALL PRIVILEGES ON `${db.name}`.* TO '${db.username}'@'%';
          FLUSH PRIVILEGES;
        '';
      }) cfg.extraDatabases
    );

    nodeSelector."kubernetes.io/hostname" = cfg.hostAffinity;
    primary.persistence.storageClass = cfg.storageClass;
  };

  extraResources = cfg: {
    sopsSecrets.${password-secret} = lib.createSecret {
      inherit lib pkgs;
      inherit (config) ageRecipients;
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

    # Backup PVC for storing database backups
    persistentVolumeClaims = lib.optionalAttrs cfg.backup.enable {
      "mariadb-backups".spec = {
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = cfg.backup.storageSize;
        storageClassName = cfg.storageClass;
      };
    };

    # CronJob for automated backups
    cronJobs = lib.optionalAttrs cfg.backup.enable {
      "mariadb-backup" = {
        metadata = {
          labels = {
            "app.kubernetes.io/name" = name;
            "app.kubernetes.io/component" = "backup";
          };
        };
        spec = {
          schedule = cfg.backup.schedule;
          successfulJobsHistoryLimit = 3;
          failedJobsHistoryLimit = 3;
          jobTemplate = {
            spec = {
              template = {
                spec = {
                  restartPolicy = "OnFailure";
                  containers = [
                    {
                      name = "backup";
                      image = "bitnami/mariadb:latest";
                      command = [
                        "/bin/bash"
                        "-c"
                        ''
                          set -e
                          BACKUP_DIR="/backups"
                          TIMESTAMP=$(date +%Y%m%d_%H%M%S)
                          BACKUP_FILE="$BACKUP_DIR/mariadb-backup-$TIMESTAMP.sql.gz"

                          echo "Starting backup at $(date)"

                          # Create backup
                          mysqldump \
                            -h mariadb.mariadb \
                            -u root \
                            -p"$MARIADB_ROOT_PASSWORD" \
                            --all-databases \
                            --single-transaction \
                            --quick \
                            --lock-tables=false \
                            | gzip > "$BACKUP_FILE"

                          echo "Backup completed: $BACKUP_FILE"
                          echo "Backup size: $(du -h "$BACKUP_FILE" | cut -f1)"

                          # Clean up old backups (keep last ${toString cfg.backup.retentionDays} days)
                          find "$BACKUP_DIR" -name "mariadb-backup-*.sql.gz" -type f -mtime +${toString cfg.backup.retentionDays} -delete

                          echo "Cleanup completed. Remaining backups:"
                          ls -lh "$BACKUP_DIR"/*.sql.gz 2>/dev/null || echo "No backups found"

                          echo "Backup job completed at $(date)"
                        ''
                      ];
                      env = [
                        {
                          name = "MARIADB_ROOT_PASSWORD";
                          valueFrom = {
                            secretKeyRef = {
                              name = password-secret;
                              key = "mariadb-root-password";
                            };
                          };
                        }
                      ];
                      volumeMounts = [
                        {
                          name = "backup-storage";
                          mountPath = "/backups";
                        }
                      ];
                    }
                  ];
                  volumes = [
                    {
                      name = "backup-storage";
                      persistentVolumeClaim = {
                        claimName = "mariadb-backups";
                      };
                    }
                  ];
                };
              };
            };
          };
        };
      };
    };

    # ConfigMap with restore script
    configMaps = lib.optionalAttrs cfg.backup.enable {
      "mariadb-restore-script" = {
        data = {
          "restore.sh" = ''
            #!/bin/bash
            # MariaDB Restore Script
            # Usage: restore.sh <backup-file.sql.gz>

            set -e

            if [ -z "$1" ]; then
              echo "Usage: $0 <backup-file.sql.gz>"
              echo "Available backups:"
              ls -lh /backups/*.sql.gz 2>/dev/null || echo "No backups found"
              exit 1
            fi

            BACKUP_FILE="$1"

            if [ ! -f "$BACKUP_FILE" ]; then
              echo "Error: Backup file not found: $BACKUP_FILE"
              exit 1
            fi

            echo "Starting restore from: $BACKUP_FILE"
            echo "This will replace all existing databases!"
            read -p "Are you sure? (yes/no): " confirm

            if [ "$confirm" != "yes" ]; then
              echo "Restore cancelled"
              exit 0
            fi

            echo "Restoring database..."
            gunzip -c "$BACKUP_FILE" | mysql \
              -h mariadb.mariadb \
              -u root \
              -p"$MARIADB_ROOT_PASSWORD"

            echo "Restore completed successfully!"
          '';
        };
      };
    };
  };
}
