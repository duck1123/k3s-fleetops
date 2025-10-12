{ ageRecipients, config, lib, pkgs, ... }:
with lib;
mkArgoApp { inherit config lib; } rec {
  name = "ersatztv";
  uses-ingress = true;

  extraOptions = {
    image = mkOption {
      description = mdDoc "The docker image";
      type = types.str;
      default = "jasongdove/ersatztv:latest";
    };

    service.port = mkOption {
      description = mdDoc "The service port";
      type = types.int;
      default = 8409;
    };

    storageClassName = mkOption {
      description = mdDoc "The storage class";
      type = types.str;
      default = "longhorn";
    };

    nfs = {
      enable = mkOption {
        description = mdDoc "Enable NFS for media volume";
        type = types.bool;
        default = true;
      };

      server = mkOption {
        description = mdDoc "NFS server hostname/IP";
        type = types.str;
        default = "nasnix";
      };

      path = mkOption {
        description = mdDoc "NFS server path";
        type = types.str;
        default = "/mnt/media";
      };
    };

    tz = mkOption {
      description = mdDoc "The timezone";
      type = types.str;
      default = "Etc/UTC";
    };

    logLevel = mkOption {
      description = mdDoc "The log level (Debug, Information, Warning, Error)";
      type = types.str;
      default = "Information";
    };
  };

  extraResources = cfg: {
    deployments = {
      ersatztv = {
        metadata.labels = {
          "app.kubernetes.io/instance" = name;
          "app.kubernetes.io/name" = name;
          "app.kubernetes.io/version" = "latest";
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
              initContainers = [{
                name = "db-init";
                image = cfg.image;
                imagePullPolicy = "IfNotPresent";
                command = ["sh"];
                args = ["-c" "chmod -R 755 /app/data"];
                volumeMounts = [
                  {
                    mountPath = "/app/data";
                    name = "data";
                  }
                ];
              }];
              containers = [{
                inherit name;
                image = cfg.image;
                imagePullPolicy = "IfNotPresent";
                env = [
                  {
                    name = "TZ";
                    value = cfg.tz;
                  }
                  {
                    name = "ERSATZTV_PORT";
                    value = "${toString cfg.service.port}";
                  }
                  {
                    name = "ASPNETCORE_ENVIRONMENT";
                    value = "Production";
                  }
                  {
                    name = "ASPNETCORE_URLS";
                    value = "http://0.0.0.0:${toString cfg.service.port}";
                  }
                  {
                    name = "Logging__LogLevel__Default";
                    value = cfg.logLevel;
                  }
                ];

                # livenessProbe = {
                #   failureThreshold = 3;
                #   initialDelaySeconds = 120;
                #   periodSeconds = 30;
                #   httpGet = {
                #     path = "/";
                #     port = cfg.service.port;
                #   };
                # };

                # readinessProbe = {
                #   failureThreshold = 30;
                #   initialDelaySeconds = 60;
                #   periodSeconds = 10;
                #   httpGet = {
                #     path = "/";
                #     port = cfg.service.port;
                #   };
                # };

                ports = [{
                  containerPort = cfg.service.port;
                  name = "http";
                  protocol = "TCP";
                }];

                volumeMounts = [
                  {
                    mountPath = "/media";
                    name = "media";
                  }
                  {
                    mountPath = "/app/data";
                    name = "data";
                  }
                ];
              }];
              volumes = [
                {
                  name = "media";
                  persistentVolumeClaim.claimName = "${name}-${name}-media";
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

    ingresses.${name}.spec = with cfg.ingress; {
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

    persistentVolumeClaims = {
      "${name}-${name}-media".spec = if cfg.nfs.enable then {
        accessModes = [ "ReadWriteMany" ];
        resources.requests.storage = "1Gi";
        storageClassName = "";
        volumeName = "${name}-${name}-media-nfs";
      } else {
        inherit (cfg) storageClassName;
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "10Gi";
      };
      "${name}-${name}-data".spec = {
        inherit (cfg) storageClassName;
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "5Gi";
      };
    };

    services = {
      ${name}.spec = {
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
    };

    # Create NFS PersistentVolume for media when NFS is enabled
    persistentVolumes = lib.optionalAttrs cfg.nfs.enable {
      "${name}-${name}-media-nfs" = {
        apiVersion = "v1";
        kind = "PersistentVolume";
        metadata = {
          name = "${name}-${name}-media-nfs";
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
  };
}
