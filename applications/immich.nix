{ ... }:
{
  flake.nixidyApps.immich =
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
    self.lib.mkArgoApp
      {
        inherit
          config
          lib
          self
          pkgs
          ;
      }
      rec {
        name = "immich";
        uses-ingress = true;

        sopsSecrets = cfg: {
          ${password-secret} = {
            inherit (cfg.database) password username;
          };
          ${redis-secret} = {
            password = cfg.redis.password;
          };
        };

        extraAppConfig = cfg: {
          annotations."argocd.argoproj.io/sync-wave" = "2";
        };

        # https://github.com/immich-app/immich-charts
        chart = lib.helm.downloadHelmChart {
          repo = "oci://ghcr.io/immich-app/immich-charts";
          chart = "immich";
          version = "0.11.1";
          chartHash = "sha256-d0N+3T+bFVYnJ1xvO94SRTecqVWovhi/KbMA0wJ+LzU=";
        };

        extraOptions = {
          image.tag = mkOption {
            description = mdDoc "The docker image tag";
            type = types.str;
            default = "release";
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

          externalLibrary = {
            enable = mkOption {
              description = mdDoc "Mount an NFS share as an external library (read-only) at /mnt/external-library";
              type = types.bool;
              default = false;
            };

            server = mkOption {
              description = mdDoc "NFS server hostname/IP for external library";
              type = types.str;
              default = "nasnix";
            };

            path = mkOption {
              description = mdDoc "NFS server path for external library";
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
              library = {
                existingClaim = "${name}-${name}-library";
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
            }
            // (lib.optionalAttrs cfg.externalLibrary.enable {
              external-library = {
                existingClaim = "${name}-${name}-external-library";
                globalMounts = [ { path = "/mnt/external-library"; readOnly = true; } ];
              };
            });
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

          # Create NFS PersistentVolumes when NFS options are enabled
          persistentVolumes =
            (lib.optionalAttrs cfg.nfs.enable {
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
            })
            // (lib.optionalAttrs cfg.externalLibrary.enable {
              "${name}-${name}-external-library-nfs" = {
                apiVersion = "v1";
                kind = "PersistentVolume";
                metadata = {
                  name = "${name}-${name}-external-library-nfs";
                };
                spec = {
                  capacity = {
                    storage = "1Ti";
                  };
                  accessModes = [ "ReadOnlyMany" ];
                  mountOptions = [
                    "nolock"
                    "soft"
                    "timeo=30"
                  ];
                  nfs = {
                    server = cfg.externalLibrary.server;
                    path = cfg.externalLibrary.path;
                  };
                  persistentVolumeReclaimPolicy = "Retain";
                };
              };
            });

          # Create PVC for NFS library volume when NFS is enabled
          persistentVolumeClaims =
            {
              "${name}-${name}-library".spec =
                if cfg.nfs.enable then
                  {
                    accessModes = [ "ReadWriteMany" ];
                    resources.requests.storage = "1Gi";
                    storageClassName = "";
                    volumeName = "${name}-${name}-library-nfs";
                  }
                else
                  {
                    inherit (cfg) storageClassName;
                    accessModes = [ "ReadWriteOnce" ];
                    resources.requests.storage = "100Gi";
                  };
            }
            // (lib.optionalAttrs cfg.externalLibrary.enable {
              "${name}-${name}-external-library".spec = {
                accessModes = [ "ReadOnlyMany" ];
                resources.requests.storage = "1Gi";
                storageClassName = "";
                volumeName = "${name}-${name}-external-library-nfs";
              };
            });

          # Job to enable vector extension in PostgreSQL database
          # Uses ArgoCD sync hook to run after secrets are created but before Immich is deployed
          jobs = {
            "${name}-enable-vector-extension" = {
              metadata = {
                annotations = {
                  "argocd.argoproj.io/hook" = "Sync";
                  "argocd.argoproj.io/hook-delete-policy" = "BeforeHookCreation,HookSucceeded";
                  "argocd.argoproj.io/sync-wave" = "1";
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
      };
}
