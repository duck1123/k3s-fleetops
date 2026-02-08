{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
mkArgoApp { inherit config lib; } rec {
  name = "booklore";
  uses-ingress = true;

  extraOptions = {
    database = {
      host = mkOption {
        description = mdDoc "The database host";
        type = types.str;
        default = "mariadb";
      };

      name = mkOption {
        description = mdDoc "The database name";
        type = types.str;
        default = "booklore";
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
        default = "booklore";
      };
    };

    gid = mkOption {
      description = mdDoc "The group id";
      type = types.str;
      default = "1000";
    };

    image = mkOption {
      description = mdDoc "The docker image";
      type = types.str;
      default = "booklore/booklore:latest";
    };

    service.port = mkOption {
      description = mdDoc "The service port";
      type = types.int;
      default = 6060;
    };

    storageClassName = mkOption {
      description = mdDoc "The storage class";
      type = types.str;
      default = "longhorn";
    };

    nfs = {
      enable = mkOption {
        description = mdDoc "Enable NFS for books volume";
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
        default = "/mnt/books";
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
    deployments = {
      booklore = {
        metadata.labels = {
          "app.kubernetes.io/instance" = name;
          "app.kubernetes.io/name" = name;
          "app.kubernetes.io/version" = "0.8.7";
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
                      name = "DATABASE_URL";
                      value = "jdbc:mariadb://${cfg.database.host}:${toString cfg.database.port}/${cfg.database.name}";
                    }
                    {
                      name = "DATABASE_USERNAME";
                      value = cfg.database.username;
                    }
                    {
                      name = "DATABASE_PASSWORD";
                      valueFrom.secretKeyRef = {
                        name = "booklore-database-password";
                        key = "password";
                      };
                    }
                    {
                      name = "BOOKLORE_PORT";
                      value = "${toString cfg.service.port}";
                    }
                    {
                      name = "SWAGGER_ENABLED";
                      value = "false";
                    }
                  ];

                  livenessProbe = {
                    failureThreshold = 3;
                    initialDelaySeconds = 0;
                    periodSeconds = 10;
                    tcpSocket.port = 6060;
                  };

                  ports = [
                    {
                      containerPort = 6060;
                      name = "http";
                      protocol = "TCP";
                    }
                  ];

                  volumeMounts = [
                    {
                      mountPath = "/bookdrop";
                      name = "bookdrop";
                    }
                    {
                      mountPath = "/books";
                      name = "books";
                    }
                    {
                      mountPath = "/app/data";
                      name = "data";
                    }
                  ];
                }
              ];
              volumes = [
                {
                  name = "bookdrop";
                  persistentVolumeClaim.claimName = "${name}-${name}-bookdrop";
                }
                {
                  name = "books";
                  persistentVolumeClaim.claimName = "${name}-${name}-books";
                }
                {
                  name = "data";
                  persistentVolumeClaim.claimName = "${name}-${name}-data";
                }
              ];
            };
          };
        };
      };
    };

    ingresses = {
      ${name} = {
        spec = with cfg.ingress; {
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
      "${name}-${name}-bookdrop".spec = {
        inherit (cfg) storageClassName;
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "5Gi";
      };
      "${name}-${name}-books".spec =
        if cfg.nfs.enable then
          {
            accessModes = [ "ReadWriteMany" ];
            resources.requests.storage = "1Gi";
            storageClassName = "";
            volumeName = "${name}-${name}-books-nfs";
          }
        else
          {
            inherit (cfg) storageClassName;
            accessModes = [ "ReadWriteOnce" ];
            resources.requests.storage = "5Gi";
          };
      "${name}-${name}-data".spec = {
        inherit (cfg) storageClassName;
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "5Gi";
      };
    };

    services = {
      ${name}.spec = {
        ports = [
          {
            name = "http";
            port = 6060;
            protocol = "TCP";
            targetPort = "http";
          }
        ];

        selector = {
          "app.kubernetes.io/instance" = name;
          "app.kubernetes.io/name" = name;
        };

        type = "ClusterIP";
      };
    };

    # Create NFS PersistentVolume for books when NFS is enabled
    persistentVolumes = lib.optionalAttrs cfg.nfs.enable {
      "${name}-${name}-books-nfs" = {
        apiVersion = "v1";
        kind = "PersistentVolume";
        metadata = {
          name = "${name}-${name}-books-nfs";
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

    # Create a secret in booklore namespace that references MariaDB secret
    sopsSecrets.booklore-database-password = self.lib.createSecret {
      inherit lib pkgs;
      inherit (config) ageRecipients;
      inherit (cfg) namespace;
      secretName = "booklore-database-password";
      values.password = cfg.database.password;
    };
  };
}
