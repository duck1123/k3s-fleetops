{ ageRecipients, config, lib, pkgs, ... }:
with lib;
let password-secret = "romm-database-password";
    admin-secret = "romm-admin-password";
in mkArgoApp { inherit config lib; } rec {
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
            containers = [{
              inherit name;
              image = cfg.image;
              imagePullPolicy = "IfNotPresent";
              env = [
                {
                  name = "DATABASE_URL";
                  value = "mariadb://${cfg.database.username}@${cfg.database.host}:${toString cfg.database.port}/${cfg.database.name}";
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
              ];

              ports = [{
                containerPort = cfg.service.port;
                name = "http";
                protocol = "TCP";
              }];

              volumeMounts = [
                {
                  mountPath = "/app/data";
                  name = "data";
                }
                {
                  mountPath = "/roms";
                  name = "library";
                }
                {
                  mountPath = "/app/assets";
                  name = "assets";
                }
                {
                  mountPath = "/app/resources";
                  name = "resources";
                }
              ];
            }];
            volumes = [
              {
                name = "data";
                persistentVolumeClaim.claimName = "${name}-${name}-data";
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
          };
        };
      };
    };

    services.${name}.spec = {
      ports = [{
        name = "http";
        port = cfg.service.port;
        protocol = "TCP";
        targetPort = "http";
      }];

      selector = {
        "app.kubernetes.io/instance" = name;
        "app.kubernetes.io/name" = name;
      };
      type = "ClusterIP";
    };

    ingresses.${name} = with cfg.ingress; {
      spec = {
        inherit ingressClassName;

        rules = [{
          host = domain;
          http.paths = [{
            backend.service = {
              inherit name;
              port.name = "http";
            };
            path = "/";
            pathType = "ImplementationSpecific";
          }];
        }];
        tls = [{ hosts = [ domain ]; }];
      };
    };

    persistentVolumeClaims = {
      "${name}-${name}-data".spec = {
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "5Gi";
        storageClassName = cfg.storageClassName;
      };
      "${name}-library".spec = if cfg.nfs.enable then {
        accessModes = [ "ReadWriteMany" ];
        resources.requests.storage = "1Gi";
        storageClassName = "";
        volumeName = "${name}-${name}-library-nfs";
      } else {
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "5Gi";
        storageClassName = cfg.storageClassName;
      };
      "${name}-assets".spec = if cfg.nfs.enable then {
        accessModes = [ "ReadWriteMany" ];
        resources.requests.storage = "1Gi";
        storageClassName = "";
        volumeName = "${name}-${name}-assets-nfs";
      } else {
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "5Gi";
        storageClassName = cfg.storageClassName;
      };
      "${name}-resources".spec = if cfg.nfs.enable then {
        accessModes = [ "ReadWriteMany" ];
        resources.requests.storage = "1Gi";
        storageClassName = "";
        volumeName = "${name}-${name}-resources-nfs";
      } else {
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
