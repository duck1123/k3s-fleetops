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

      storage.className = cfg.storageClass;
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
                      value = cfg.auth.adminUsername;
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
                          SELECT 'CREATE DATABASE ${db.name}' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${db.name}')\gexec

                          -- Create user if it doesn't exist
                          DO \$\$
                          BEGIN
                            IF NOT EXISTS (SELECT FROM pg_user WHERE usename = '${db.username}') THEN
                              EXECUTE format('CREATE USER %I WITH PASSWORD %L', '${db.username}', '${db.password}');
                            END IF;
                          END
                          \$\$;

                          -- Grant privileges
                          GRANT ALL PRIVILEGES ON DATABASE ${db.name} TO ${db.username};
                          ALTER DATABASE ${db.name} OWNER TO ${db.username};
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
  };
}
