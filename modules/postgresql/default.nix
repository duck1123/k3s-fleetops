{ ageRecipients, config, lib, pkgs, ... }:
with lib;
let password-secret = "postgresql-password";
in mkArgoApp { inherit config lib; } rec {
  name = "postgresql";

  # https://artifacthub.io/packages/helm/bitnami/redis
  chart = lib.helm.downloadHelmChart {
    repo = "https://groundhog2k.github.io/helm-charts/";
    chart = "postgres";
    version = "1.5.8";
    chartHash = "sha256-Ev3NhEPrTWoAfFDlkYw6N88lstU2OOUJ8SEWY10pxxw=";
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

    image = mkOption {
      description =
        mdDoc "The PostgreSQL image (should include pgvector for Immich)";
      type = types.str;
      default = "pgvector/pgvector:pg17";
    };

    storageClass = mkOption {
      description = mdDoc "The storage class to use for persistence";
      type = types.str;
      default = "local-path";
    };

    persistenceSize = mkOption {
      description = mdDoc "Size of the persistent volume";
      type = types.str;
      default = "20Gi";
    };

    persistenceEnabled = mkOption {
      description = mdDoc "Enable persistent storage for PostgreSQL";
      type = types.bool;
      default = true;
    };

    backup = {
      enable = mkOption {
        description = mdDoc "Enable automated database backups";
        type = types.bool;
        default = true;
      };

      schedule = mkOption {
        description =
          mdDoc "Cron schedule for backups (default: daily at 2 AM)";
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

    extraDatabases = mkOption {
      description = mdDoc "Additional databases to create (list of {name, username, password})";
      type = types.listOf (types.submodule {
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
      });
      default = [ ];
    };
  };

  defaultValues = cfg:
    let
      imageStr = cfg.image;
      parts = lib.splitString "/" imageStr;
      hasExplicitRegistry = lib.length parts > 2
        || (lib.length parts == 2 && lib.hasInfix "." (lib.head parts));
      registry = if hasExplicitRegistry then lib.head parts else "docker.io";
      repoAndTag = if hasExplicitRegistry then
        lib.concatStringsSep "/" (lib.tail parts)
      else
        lib.concatStringsSep "/" parts;
      tagParts = lib.splitString ":" repoAndTag;
      repository = lib.head tagParts;
      tag = if lib.length tagParts > 1 then lib.last tagParts else "latest";
    in {
      image = { inherit registry repository tag; };

      settings = {
        existingSecret = password-secret;
        superuserPassword.secretKey = "adminPassword";
      };

      # Enable persistence with PVC
      persistence = {
        enabled = cfg.persistenceEnabled;
        size = cfg.persistenceSize;
        storageClass = cfg.storageClass;
      };

      # Also set storage.className for compatibility
      storage = {
        className = cfg.storageClass;
        size = cfg.persistenceSize;
      };

      # Run on edgenix node only
      nodeSelector = {
        "kubernetes.io/hostname" = "edgenix";
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

    # Create a Job to initialize extra databases after PostgreSQL is ready
    jobs = lib.optionalAttrs (cfg.extraDatabases != []) {
      "${name}-init-databases" = {
        metadata = {
          name = "${name}-init-databases";
          namespace = cfg.namespace;
          annotations = {
            "argocd.argoproj.io/hook" = "PostSync";
            "argocd.argoproj.io/hook-delete-policy" = "HookSucceeded";
          };
        };
        spec = {
          template = {
            spec = {
              restartPolicy = "OnFailure";
              containers = [
                {
                  name = "init-databases";
                  image = cfg.image;
                  imagePullPolicy = "IfNotPresent";
                  env = [
                    {
                      name = "PGHOST";
                      value = "${name}.${cfg.namespace}";
                    }
                    {
                      name = "PGPORT";
                      value = "5432";
                    }
                    {
                      name = "PGUSER";
                      value = "postgres";
                    }
                    {
                      name = "PGPASSWORD";
                      valueFrom = {
                        secretKeyRef = {
                          name = password-secret;
                          key = "adminPassword";
                        };
                      };
                    }
                  ];
                  command = [
                    "sh"
                    "-c"
                    ''
                      set -e
                      ${lib.concatMapStringsSep "\n" (db: ''
                        echo "Creating database ${db.name} and user ${db.username}..."
                        psql -v ON_ERROR_STOP=1 <<-EOSQL
                          -- Create database if it doesn't exist
                          SELECT format('CREATE DATABASE %I', '${db.name}') WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${db.name}')\gexec

                          -- Create user if it doesn't exist, then always update password
                          DO \$\$
                          BEGIN
                            IF NOT EXISTS (SELECT FROM pg_user WHERE usename = '${db.username}') THEN
                              EXECUTE format('CREATE USER %I WITH PASSWORD %L', '${db.username}', '${db.password}');
                            ELSE
                              EXECUTE format('ALTER USER %I WITH PASSWORD %L', '${db.username}', '${db.password}');
                            END IF;
                          END
                          \$\$;

                          -- Grant privileges (quote database name)
                          DO \$\$
                          BEGIN
                            EXECUTE format('GRANT ALL PRIVILEGES ON DATABASE %I TO %I', '${db.name}', '${db.username}');
                            EXECUTE format('ALTER DATABASE %I OWNER TO %I', '${db.name}', '${db.username}');
                          END
                          \$\$;
                        EOSQL
                        echo "Database ${db.name} created successfully"
                      '') cfg.extraDatabases}
                    ''
                  ];
                }
              ];
            };
          };
        };
      };
    };

    # CronJob for automated backups
    cronJobs = lib.optionalAttrs cfg.backup.enable {
      "${name}-backup" = {
        metadata = {
          name = "${name}-backup";
          namespace = cfg.namespace;
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
                  containers = [{
                    name = "backup";
                    image = cfg.image;
                    command = [
                      "sh"
                      "-c"
                      ''
                        set -e
                        BACKUP_DIR="/backups"
                        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
                        BACKUP_FILE="$BACKUP_DIR/postgresql-backup-$TIMESTAMP.sql.gz"

                        echo "Starting backup at $(date)"

                        # Create backup of all databases
                        pg_dumpall \
                          -h ${name}.${cfg.namespace} \
                          -U postgres \
                          -c \
                          | gzip > "$BACKUP_FILE"

                        echo "Backup completed: $BACKUP_FILE"
                        echo "Backup size: $(du -h "$BACKUP_FILE" | cut -f1)"

                        # Clean up old backups (keep last ${toString cfg.backup.retentionDays} days)
                        find "$BACKUP_DIR" -name "postgresql-backup-*.sql.gz" -type f -mtime +${
                          toString cfg.backup.retentionDays
                        } -delete

                        echo "Cleanup completed. Remaining backups:"
                        ls -lh "$BACKUP_DIR"/*.sql.gz 2>/dev/null || echo "No backups found"

                        echo "Backup job completed at $(date)"
                      ''
                    ];
                    env = [{
                      name = "PGPASSWORD";
                      valueFrom = {
                        secretKeyRef = {
                          name = password-secret;
                          key = "adminPassword";
                        };
                      };
                    }];
                    volumeMounts = [{
                      mountPath = "/backups";
                      name = "backup-storage";
                    }];
                  }];
                  volumes = [{
                    name = "backup-storage";
                    persistentVolumeClaim = {
                      claimName = "${name}-backups";
                    };
                  }];
                };
              };
            };
          };
        };
      };
    };

    # PVC for backup storage
    persistentVolumeClaims = lib.optionalAttrs cfg.backup.enable {
      "${name}-backups" = {
        metadata = {
          name = "${name}-backups";
          namespace = cfg.namespace;
        };
        spec = {
          accessModes = [ "ReadWriteOnce" ];
          resources = {
            requests = {
              storage = cfg.backup.storageSize;
            };
          };
          storageClassName = cfg.storageClass;
        };
      };
    };

    # Patch StatefulSet to add volumeClaimTemplates for persistence
    # The Helm chart isn't respecting persistence.enabled, so we patch it directly
    # We also need to remove the emptyDir volume for postgres-data from the pod template
    statefulSets = lib.optionalAttrs cfg.persistenceEnabled {
      ${name} = {
        spec = {
          volumeClaimTemplates = [{
            metadata = {
              name = "postgres-data";
              labels = {
                "app.kubernetes.io/instance" = name;
                "app.kubernetes.io/name" = "postgres";
              };
            };
            spec = {
              accessModes = [ "ReadWriteOnce" ];
              resources = {
                requests = {
                  storage = cfg.persistenceSize;
                };
              };
              storageClassName = cfg.storageClass;
            };
          }];
          # Override volumes list to remove postgres-data emptyDir
          # Keep all other volumes: run, tmp, scripts, configs, initscripts
          template = {
            spec = {
              volumes = [
                { name = "run"; emptyDir = {}; }
                { name = "tmp"; emptyDir = {}; }
                { name = "scripts"; emptyDir = {}; }
                { name = "configs"; emptyDir = {}; }
                {
                  name = "initscripts";
                  configMap = {
                    name = "${name}-scripts";
                    defaultMode = 365;
                  };
                }
                # postgres-data is provided by volumeClaimTemplates, so we don't include it here
              ];
            };
          };
        };
      };
    };
  };
}
