{
  config,
  lib,
  pkgs,
  self,
  ...
}:
with lib;
let
  password-secret = "immich-database-password";
  redis-secret = "immich-redis-password";
in
self.lib.mkArgoApp { inherit config lib; } rec {
  name = "immich";
  uses-ingress = true;

  # https://github.com/immich-app/immich-charts
  # Chart is pulled via OCI and stored in chart-archives/
  # Run: helm pull oci://ghcr.io/immich-app/immich-charts/immich --version 0.10.3
  chart = self.lib.helmChart {
    inherit pkgs;
    chartTgz = ../../chart-archives/immich-0.10.3.tgz;
    chartName = "immich";
  };

  extraOptions = {
    image.tag = mkOption {
      description = mdDoc "The docker image tag";
      type = types.str;
      default = "release";
    };

    storageClassName = mkOption {
      description = mdDoc "The storage class";
      type = types.str;
      default = "longhorn";
    };

    database = {
      host = mkOption {
        description = mdDoc "The database host";
        type = types.str;
        default = "postgresql";
      };

      name = mkOption {
        description = mdDoc "The database name";
        type = types.str;
        default = "immich";
      };

      password = mkOption {
        description = mdDoc "The database password";
        type = types.str;
        default = "CHANGEME";
      };

      port = mkOption {
        description = mdDoc "The database port";
        type = types.int;
        default = 5432;
      };

      username = mkOption {
        description = mdDoc "The database username";
        type = types.str;
        default = "immich";
      };
    };

    redis = {
      host = mkOption {
        description = mdDoc "The Redis host";
        type = types.str;
        default = "redis";
      };

      port = mkOption {
        description = mdDoc "The Redis port";
        type = types.int;
        default = 6379;
      };

      password = mkOption {
        description = mdDoc "The Redis password";
        type = types.str;
        default = "CHANGEME";
      };

      dbIndex = mkOption {
        description = mdDoc "The Redis database index";
        type = types.int;
        default = 0;
      };
    };

    nfs = {
      enable = mkOption {
        description = mdDoc "Enable NFS for library volume";
        type = types.bool;
        default = false;
      };

      server = mkOption {
        description = mdDoc "NFS server hostname/IP";
        type = types.str;
        default = "nasnix";
      };

      path = mkOption {
        description = mdDoc "NFS server path";
        type = types.str;
        default = "/mnt/photos";
      };
    };
  };

  defaultValues = cfg: {
    # Disable built-in Redis (Valkey)
    # Note: postgresql subchart was removed in 0.10.0, must be deployed separately
    valkey.enabled = false;

    # Environment variables for all Immich components
    controllers = {
      main = {
        containers = {
          main = {
            env = {
              DB_HOSTNAME = cfg.database.host;
              DB_PORT = "${toString cfg.database.port}";
              DB_USERNAME = {
                valueFrom = {
                  secretKeyRef = {
                    name = password-secret;
                    key = "username";
                  };
                };
              };
              DB_PASSWORD = {
                valueFrom = {
                  secretKeyRef = {
                    name = password-secret;
                    key = "password";
                  };
                };
              };
              DB_DATABASE_NAME = cfg.database.name;

              # Redis configuration - override default valkey hostname
              REDIS_HOSTNAME = cfg.redis.host;
              REDIS_PORT = "${toString cfg.redis.port}";
              REDIS_PASSWORD = {
                valueFrom = {
                  secretKeyRef = {
                    name = redis-secret;
                    key = "password";
                  };
                };
              };
              REDIS_DBINDEX = "${toString cfg.redis.dbIndex}";
            };
          };
        };
      };
    };

    immich = {
      image.tag = cfg.image.tag;

      # Persistence configuration
      persistence = {
        library =
          if cfg.nfs.enable then
            {
              existingClaim = "${name}-${name}-library";
            }
          else
            {
              enabled = true;
              storageClass = cfg.storageClassName;
              accessMode = "ReadWriteOnce";
              size = "100Gi";
            };
        upload = {
          enabled = true;
          storageClass = cfg.storageClassName;
          accessMode = "ReadWriteOnce";
          size = "10Gi";
        };
        thumbs = {
          enabled = true;
          storageClass = cfg.storageClassName;
          accessMode = "ReadWriteOnce";
          size = "50Gi";
        };
        ml = {
          enabled = true;
          storageClass = cfg.storageClassName;
          accessMode = "ReadWriteOnce";
          size = "10Gi";
        };
        config = {
          enabled = true;
          storageClass = cfg.storageClassName;
          accessMode = "ReadWriteOnce";
          size = "1Gi";
        };
      };
    };

    ingress.main.enabled = false;
  };

  extraResources = cfg: {
    ingresses.${name} = {
      metadata.annotations."cert-manager.io/cluster-issuer" = cfg.ingress.clusterIssuer;

      spec = with cfg.ingress; {
        inherit ingressClassName;

        rules = [
          {
            host = domain;

            http.paths = [
              {
                backend.service = {
                  name = "${name}-server";
                  port.name = "http";
                };

                path = "/";
                pathType = "ImplementationSpecific";
              }
            ];
          }
        ];

        tls = [ { hosts = [ domain ]; } ];
      };
    };

    # Create NFS PersistentVolume for library when NFS is enabled
    persistentVolumes = lib.optionalAttrs cfg.nfs.enable {
      "${name}-${name}-library-nfs" = {
        apiVersion = "v1";
        kind = "PersistentVolume";
        metadata = {
          name = "${name}-${name}-library-nfs";
        };
        spec = {
          capacity = {
            storage = "1Ti";
          };
          accessModes = [ "ReadWriteMany" ];
          mountOptions = [
            "nolock"
            "soft"
            "timeo=30"
          ];
          nfs = {
            server = cfg.nfs.server;
            path = cfg.nfs.path;
          };
          persistentVolumeReclaimPolicy = "Retain";
        };
      };
    };

    # Create PVC for NFS library volume when NFS is enabled
    persistentVolumeClaims = lib.optionalAttrs cfg.nfs.enable {
      "${name}-${name}-library".spec = {
        accessModes = [ "ReadWriteMany" ];
        resources.requests.storage = "1Gi";
        storageClassName = "";
        volumeName = "${name}-${name}-library-nfs";
      };
    };

    # Create secrets for database and Redis
    sopsSecrets.${password-secret} = self.lib.createSecret {
      inherit lib pkgs;
      inherit (config) ageRecipients;
      inherit (cfg) namespace;
      secretName = password-secret;
      values = {
        password = cfg.database.password;
        username = cfg.database.username;
      };
    };

    sopsSecrets.${redis-secret} = self.lib.createSecret {
      inherit lib pkgs;
      inherit (config) ageRecipients;
      inherit (cfg) namespace;
      secretName = redis-secret;
      values.password = cfg.redis.password;
    };

    # Job to enable vector extension in PostgreSQL database
    # Uses ArgoCD sync hook to run before Immich is deployed
    jobs = {
      "${name}-enable-vector-extension" = {
        metadata = {
          annotations = {
            "argocd.argoproj.io/hook" = "PreSync";
            "argocd.argoproj.io/hook-delete-policy" = "BeforeHookCreation,HookSucceeded";
          };
        };
        spec = {
          backoffLimit = 3;
          template = {
            spec = {
              restartPolicy = "OnFailure";
              containers = [
                {
                  name = "enable-vector-extension";
                  image = "docker.io/postgres:17.6";
                  imagePullPolicy = "IfNotPresent";
                  command = [ "psql" ];
                  args = [
                    "-h"
                    cfg.database.host
                    "-p"
                    "${toString cfg.database.port}"
                    "-U"
                    cfg.database.username
                    "-d"
                    cfg.database.name
                    "-c"
                    "CREATE EXTENSION IF NOT EXISTS vector;"
                  ];
                  env = [
                    {
                      name = "PGPASSWORD";
                      valueFrom = {
                        secretKeyRef = {
                          name = password-secret;
                          key = "password";
                        };
                      };
                    }
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
