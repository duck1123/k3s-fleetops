{ ageRecipients, config, lib, pkgs, ... }:
with lib;
mkArgoApp { inherit config lib; } rec {
  name = "immich";
  uses-ingress = true;

  extraOptions = {
    image = mkOption {
      description = mdDoc "The docker image";
      type = types.str;
      default = "ghcr.io/immich-app/immich-server:release";
    };

    service.port = mkOption {
      description = mdDoc "The service port";
      type = types.int;
      default = 3001;
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

    tz = mkOption {
      description = mdDoc "The timezone";
      type = types.str;
      default = "Etc/UTC";
    };

    uid = mkOption {
      description = mdDoc "The user id";
      type = types.str;
      default = "1000";
    };

    gid = mkOption {
      description = mdDoc "The group id";
      type = types.str;
      default = "1000";
    };
  };

  extraResources = cfg: {
    deployments = {
      immich-server = {
        metadata.labels = {
          "app.kubernetes.io/instance" = name;
          "app.kubernetes.io/name" = "${name}-server";
          "app.kubernetes.io/component" = "server";
        };

        spec = {
          selector.matchLabels = {
            "app.kubernetes.io/instance" = name;
            "app.kubernetes.io/name" = "${name}-server";
          };

          template = {
            metadata.labels = {
              "app.kubernetes.io/instance" = name;
              "app.kubernetes.io/name" = "${name}-server";
            };

            spec = {
              automountServiceAccountToken = true;
              serviceAccountName = "default";
              containers = [{
                name = "immich-server";
                image = cfg.image;
                imagePullPolicy = "IfNotPresent";
                env = [
                  {
                    name = "USER_ID";
                    value = cfg.uid;
                  }
                  {
                    name = "GROUP_ID";
                    value = cfg.gid;
                  }
                  {
                    name = "TZ";
                    value = cfg.tz;
                  }
                  {
                    name = "DB_HOSTNAME";
                    value = cfg.database.host;
                  }
                  {
                    name = "DB_PORT";
                    value = "${toString cfg.database.port}";
                  }
                  {
                    name = "DB_USERNAME";
                    valueFrom.secretKeyRef = {
                      name = "immich-database-password";
                      key = "username";
                    };
                  }
                  {
                    name = "DB_PASSWORD";
                    valueFrom.secretKeyRef = {
                      name = "immich-database-password";
                      key = "password";
                    };
                  }
                  {
                    name = "DB_DATABASE_NAME";
                    value = cfg.database.name;
                  }
                  {
                    name = "IMMICH_UPLOAD_LOCATION";
                    value = "/usr/src/app/upload";
                  }
                  {
                    name = "IMMICH_LIBRARY_LOCATION";
                    value = "/usr/src/app/library";
                  }
                  {
                    name = "IMMICH_THUMBNAIL_LOCATION";
                    value = "/usr/src/app/thumbs";
                  }
                  {
                    name = "IMMICH_MACHINE_LEARNING_LOCATION";
                    value = "/usr/src/app/ml";
                  }
                ];

                ports = [{
                  containerPort = cfg.service.port;
                  name = "http";
                  protocol = "TCP";
                }];

                volumeMounts = [
                  {
                    mountPath = "/usr/src/app/library";
                    name = "library";
                  }
                  {
                    mountPath = "/usr/src/app/upload";
                    name = "upload";
                  }
                  {
                    mountPath = "/usr/src/app/thumbs";
                    name = "thumbs";
                  }
                  {
                    mountPath = "/usr/src/app/ml";
                    name = "ml";
                  }
                  {
                    mountPath = "/usr/src/app/config";
                    name = "config";
                  }
                ];
              }];
              volumes = [
                {
                  name = "library";
                  persistentVolumeClaim.claimName = "${name}-${name}-library";
                }
                {
                  name = "upload";
                  persistentVolumeClaim.claimName = "${name}-${name}-upload";
                }
                {
                  name = "thumbs";
                  persistentVolumeClaim.claimName = "${name}-${name}-thumbs";
                }
                {
                  name = "ml";
                  persistentVolumeClaim.claimName = "${name}-${name}-ml";
                }
                {
                  name = "config";
                  persistentVolumeClaim.claimName = "${name}-${name}-config";
                }
              ];
            };
          };
        };
      };
    };

    ingresses.${name}.spec = with cfg.ingress; {
      inherit ingressClassName;

      rules = [{
        host = domain;

        http.paths = [{
          backend.service = {
            name = "${name}-server";
            port.name = "http";
          };

          path = "/";
          pathType = "ImplementationSpecific";
        }];
      }];

      tls = [{ hosts = [ domain ]; }];
    };

    persistentVolumeClaims = {
      "${name}-${name}-library".spec = if cfg.nfs.enable then {
        accessModes = [ "ReadWriteMany" ];
        resources.requests.storage = "1Gi";
        storageClassName = "";
        volumeName = "${name}-${name}-library-nfs";
      } else {
        inherit (cfg) storageClassName;
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "100Gi";
      };
      "${name}-${name}-upload".spec = {
        inherit (cfg) storageClassName;
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "10Gi";
      };
      "${name}-${name}-thumbs".spec = {
        inherit (cfg) storageClassName;
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "50Gi";
      };
      "${name}-${name}-ml".spec = {
        inherit (cfg) storageClassName;
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "10Gi";
      };
      "${name}-${name}-config".spec = {
        inherit (cfg) storageClassName;
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "1Gi";
      };
    };

    services = {
      "${name}-server".spec = {
        ports = [{
          name = "http";
          port = cfg.service.port;
          protocol = "TCP";
          targetPort = "http";
        }];

        selector = {
          "app.kubernetes.io/instance" = name;
          "app.kubernetes.io/name" = "${name}-server";
        };

        type = "ClusterIP";
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
          nfs = {
            server = cfg.nfs.server;
            path = cfg.nfs.path;
          };
          persistentVolumeReclaimPolicy = "Retain";
        };
      };
    };

    # Create a secret in immich namespace that references PostgreSQL secret
    sopsSecrets.immich-database-password = lib.createSecret {
      inherit ageRecipients lib pkgs;
      inherit (cfg) namespace;
      secretName = "immich-database-password";
      values = {
        password = cfg.database.password;
        username = cfg.database.username;
      };
    };
  };
}

