{
  ageRecipients,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  password-secret = "romm-database-password";
  admin-secret = "romm-admin-password";
in
mkArgoApp { inherit config lib; } rec {
  name = "romm";
  uses-ingress = true;

  extraOptions = {
    image = mkOption {
      description = mdDoc "The docker image to use";
      type = types.str;
      default = "ghcr.io/rommapp/romm:latest";
    };

    admin = {
      username = mkOption {
        description = mdDoc "The admin username";
        type = types.str;
        default = "admin";
      };

      password = mkOption {
        description = mdDoc "The admin password";
        type = types.str;
        default = "CHANGEME";
      };
    };

    authSecretKey = mkOption {
      description = mdDoc "The authentication secret key (used for sessions)";
      type = types.str;
      default = "CHANGEME";
    };

    database = {
      host = mkOption {
        description = mdDoc "The database host";
        type = types.str;
        default = "mariadb.mariadb";
      };

      name = mkOption {
        description = mdDoc "The database name";
        type = types.str;
        default = "romm";
      };

      password = mkOption {
        description = mdDoc "The database password";
        type = types.str;
        default = "CHANGEME";
      };

      port = mkOption {
        description = mdDoc "The database port";
        type = types.int;
        default = 3306;
      };

      username = mkOption {
        description = mdDoc "The database username";
        type = types.str;
        default = "romm";
      };
    };

    nfs = {
      enable = mkOption {
        description = mdDoc "Enable NFS for roms volumes";
        type = types.bool;
        default = false;
      };

      server = mkOption {
        description = mdDoc "NFS server hostname/IP";
        type = types.str;
        default = "nasnix";
      };

      libraryPath = mkOption {
        description = mdDoc "NFS server path for ROM library (where ROM files are stored)";
        type = types.str;
        default = "/mnt/roms";
      };

      assetsPath = mkOption {
        description = mdDoc "NFS server path for assets (metadata, covers, screenshots)";
        type = types.str;
        default = "/mnt/roms/assets";
      };

      resourcesPath = mkOption {
        description = mdDoc "NFS server path for resources (downloaded resources, templates, etc.)";
        type = types.str;
        default = "/mnt/roms/resources";
      };
    };

    service = {
      port = mkOption {
        description = mdDoc "The service port";
        type = types.int;
        default = 5000;
      };
    };

    storageClassName = mkOption {
      description = mdDoc "The storage class";
      type = types.str;
      default = "longhorn";
    };

    ingress.localIngress = {
      enable = mkOption {
        description = mdDoc "Enable a local-only ingress using Traefik";
        type = types.bool;
        default = false;
      };

      domain = mkOption {
        description = mdDoc "The local domain to expose ${name} to (e.g., ${name}.local)";
        type = types.str;
        default = "${name}.local";
      };

      tls = {
        enable = mkOption {
          description = mdDoc "Enable TLS for local ingress";
          type = types.bool;
          default = false;
        };
      };
    };
  };

  extraResources = cfg: {
    deployments.${name} = {
      metadata.labels = {
        "app.kubernetes.io/instance" = name;
        "app.kubernetes.io/name" = name;
      };

      spec = {
        selector.matchLabels = {
          "app.kubernetes.io/instance" = name;
          "app.kubernetes.io/name" = name;
        };

        template = {
          metadata.labels = {
            "app.kubernetes.io/instance" = name;
            "app.kubernetes.io/name" = name;
          };

          spec = {
            automountServiceAccountToken = true;
            serviceAccountName = "default";
            containers = [
              {
                inherit name;
                image = cfg.image;
                imagePullPolicy = "IfNotPresent";
                env = [
                  # Try DB_* format (without DATABASE_ prefix)
                  {
                    name = "DB_HOST";
                    value = cfg.database.host;
                  }
                  {
                    name = "DB_PORT";
                    value = "${toString cfg.database.port}";
                  }
                  {
                    name = "DB_NAME";
                    value = cfg.database.name;
                  }
                  {
                    name = "DB_USER";
                    value = cfg.database.username;
                  }
                  {
                    name = "DB_PASSWD";
                    valueFrom.secretKeyRef = {
                      name = password-secret;
                      key = "password";
                    };
                  }
                  # Also provide DATABASE_* format as fallback
                  {
                    name = "DATABASE_HOST";
                    value = cfg.database.host;
                  }
                  {
                    name = "DATABASE_PORT";
                    value = "${toString cfg.database.port}";
                  }
                  {
                    name = "DATABASE_NAME";
                    value = cfg.database.name;
                  }
                  {
                    name = "DATABASE_USER";
                    value = cfg.database.username;
                  }
                  {
                    name = "DATABASE_PASSWORD";
                    valueFrom.secretKeyRef = {
                      name = password-secret;
                      key = "password";
                    };
                  }
                  {
                    name = "ROMM_AUTH_SECRET_KEY";
                    valueFrom.secretKeyRef = {
                      name = admin-secret;
                      key = "authSecretKey";
                    };
                  }
                  {
                    name = "ROMM_ADMIN_USERNAME";
                    valueFrom.secretKeyRef = {
                      name = admin-secret;
                      key = "username";
                    };
                  }
                  {
                    name = "ROMM_ADMIN_PASSWORD";
                    valueFrom.secretKeyRef = {
                      name = admin-secret;
                      key = "password";
                    };
                  }
                  {
                    name = "ROMM_CONFIG_PATH";
                    value = "/romm/config/config.yml";
                  }
                  # Nginx bind configuration
                  # Nginx should listen on 8080, gunicorn runs on 5000
                  # Based on Dockerfile: EXPOSE 8080 6379/tcp
                  # The nginx template likely uses PORT for the listen directive
                  {
                    name = "HOST";
                    value = "0.0.0.0";
                  }
                  {
                    name = "PORT";
                    value = "8080";
                  }
                  {
                    name = "ROMM_HOST";
                    value = "0.0.0.0";
                  }
                  {
                    name = "ROMM_PORT";
                    value = "8080";
                  }
                  {
                    name = "NGINX_PORT";
                    value = "8080";
                  }
                  {
                    name = "GUNICORN_PORT";
                    value = "${toString cfg.service.port}";
                  }
                  {
                    name = "GUNICORN_HOST";
                    value = "127.0.0.1";
                  }
                  # Valkey/Redis configuration - romm uses internal valkey by default
                  # If you want to use external Redis, uncomment and configure:
                  # {
                  #   name = "REDIS_HOST";
                  #   value = "redis.redis";
                  # }
                  # {
                  #   name = "REDIS_PORT";
                  #   value = "6379";
                  # }
                ];

                ports = [
                  {
                    containerPort = 8080;
                    name = "http";
                    protocol = "TCP";
                  }
                  {
                    containerPort = 6379;
                    name = "redis";
                    protocol = "TCP";
                  }
                ];

                volumeMounts = [
                  {
                    mountPath = "/romm/data";
                    name = "data";
                  }
                  {
                    mountPath = "/romm/config";
                    name = "config";
                  }
                  {
                    mountPath = "/romm/library";
                    name = "library";
                  }
                  {
                    mountPath = "/romm/assets";
                    name = "assets";
                  }
                  {
                    mountPath = "/romm/resources";
                    name = "resources";
                  }
                ];
              }
            ];
            volumes = [
              {
                name = "data";
                persistentVolumeClaim.claimName = "${name}-${name}-data";
              }
              {
                name = "config";
                persistentVolumeClaim.claimName = "${name}-${name}-config";
              }
              {
                name = "library";
                persistentVolumeClaim.claimName = "${name}-library";
              }
              {
                name = "assets";
                persistentVolumeClaim.claimName = "${name}-assets";
              }
              {
                name = "resources";
                persistentVolumeClaim.claimName = "${name}-resources";
              }
            ];
            # Init container to pre-create config file
            initContainers = [
              {
                name = "init-config";
                image = "busybox:latest";
                command = [
                  "sh"
                  "-c"
                  ''
                    if [ ! -f /romm/config/config.yml ]; then
                      echo "Creating initial config.yml file"
                      touch /romm/config/config.yml
                      chmod 644 /romm/config/config.yml
                    else
                      echo "config.yml already exists"
                    fi
                  ''
                ];
                volumeMounts = [
                  {
                    mountPath = "/romm/config";
                    name = "config";
                  }
                ];
              }
            ];
          };
        };
      };
    };

    services.${name}.spec = {
      ports = [
        {
          name = "http";
          port = 8080;
          protocol = "TCP";
          targetPort = "http";
        }
        {
          name = "redis";
          port = 6379;
          protocol = "TCP";
          targetPort = "redis";
        }
      ];

      selector = {
        "app.kubernetes.io/instance" = name;
        "app.kubernetes.io/name" = name;
      };
      type = "ClusterIP";
    };

    ingresses = {
      ${name} = with cfg.ingress; {
        spec = {
          inherit ingressClassName;

          rules = [
            {
              host = domain;
              http.paths = [
                {
                  backend.service = {
                    inherit name;
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
    }
    // lib.optionalAttrs (cfg.ingress.localIngress.enable) {
      # Optional local-only ingress using Traefik
      "${name}-local" = {
        spec = with cfg.ingress.localIngress; {
          ingressClassName = "traefik";

          rules = [
            {
              host = domain;
              http.paths = [
                {
                  backend.service = {
                    inherit name;
                    port.name = "http";
                  };
                  path = "/";
                  pathType = "ImplementationSpecific";
                }
              ];
            }
          ];
          tls = lib.optional tls.enable [ { hosts = [ domain ]; } ];
        };
      };
    };

    persistentVolumeClaims = {
      "${name}-${name}-data".spec = {
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "5Gi";
        storageClassName = cfg.storageClassName;
      };
      "${name}-${name}-config".spec = {
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "1Gi";
        storageClassName = cfg.storageClassName;
      };
      "${name}-library".spec =
        if cfg.nfs.enable then
          {
            accessModes = [ "ReadWriteMany" ];
            resources.requests.storage = "1Gi";
            storageClassName = "";
            volumeName = "${name}-${name}-library-nfs";
          }
        else
          {
            accessModes = [ "ReadWriteOnce" ];
            resources.requests.storage = "5Gi";
            storageClassName = cfg.storageClassName;
          };
      "${name}-assets".spec =
        if cfg.nfs.enable then
          {
            accessModes = [ "ReadWriteMany" ];
            resources.requests.storage = "1Gi";
            storageClassName = "";
            volumeName = "${name}-${name}-assets-nfs";
          }
        else
          {
            accessModes = [ "ReadWriteOnce" ];
            resources.requests.storage = "5Gi";
            storageClassName = cfg.storageClassName;
          };
      "${name}-resources".spec =
        if cfg.nfs.enable then
          {
            accessModes = [ "ReadWriteMany" ];
            resources.requests.storage = "1Gi";
            storageClassName = "";
            volumeName = "${name}-${name}-resources-nfs";
          }
        else
          {
            accessModes = [ "ReadWriteOnce" ];
            resources.requests.storage = "5Gi";
            storageClassName = cfg.storageClassName;
          };
    };

    # Create NFS PersistentVolumes for roms when NFS is enabled
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
            path = cfg.nfs.libraryPath;
          };
          persistentVolumeReclaimPolicy = "Retain";
        };
      };
      "${name}-${name}-assets-nfs" = {
        apiVersion = "v1";
        kind = "PersistentVolume";
        metadata = {
          name = "${name}-${name}-assets-nfs";
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
            path = cfg.nfs.assetsPath;
          };
          persistentVolumeReclaimPolicy = "Retain";
        };
      };
      "${name}-${name}-resources-nfs" = {
        apiVersion = "v1";
        kind = "PersistentVolume";
        metadata = {
          name = "${name}-${name}-resources-nfs";
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
            path = cfg.nfs.resourcesPath;
          };
          persistentVolumeReclaimPolicy = "Retain";
        };
      };
    };

    # Create secret for database password
    sopsSecrets.${password-secret} = lib.createSecret {
      inherit ageRecipients lib pkgs;
      inherit (cfg) namespace;
      secretName = password-secret;
      values.password = cfg.database.password;
    };

    # Create secret for admin credentials and auth secret key
    sopsSecrets.${admin-secret} = lib.createSecret {
      inherit ageRecipients lib pkgs;
      inherit (cfg) namespace;
      secretName = admin-secret;
      values = {
        username = cfg.admin.username;
        password = cfg.admin.password;
        authSecretKey = cfg.authSecretKey;
      };
    };
  };
}
