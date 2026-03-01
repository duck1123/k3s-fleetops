{
  config,
  lib,
  pkgs,
  self,
  ...
}:
with lib;
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
    name = "tunarr";
    uses-ingress = true;

    extraOptions = {
      image = mkOption {
        description = mdDoc "The docker image";
        type = types.str;
        default = "chrisbenincasa/tunarr:latest";
      };

      service.port = mkOption {
        description = mdDoc "The service port";
        type = types.int;
        default = 8000;
      };

      storageClassName = mkOption {
        description = mdDoc "The storage class";
        type = types.str;
        default = "longhorn";
      };

      nfs = {
        enable = mkOption {
          description = mdDoc "Enable NFS for TV and Movies (same base path as arr stack)";
          type = types.bool;
          default = false;
        };

        server = mkOption {
          description = mdDoc "NFS server hostname/IP";
          type = types.str;
          default = "nasnix";
        };

        path = mkOption {
          description = mdDoc "NFS server base path (e.g. /volume1); TV and Movies subpaths are used";
          type = types.str;
          default = "/mnt/media";
        };
      };

      tz = mkOption {
        description = mdDoc "The timezone for guide data and scheduling";
        type = types.str;
        default = "Etc/UTC";
      };

      logLevel = mkOption {
        description = mdDoc "Log level (trace, debug, info, warn, error, fatal, silent)";
        type = types.str;
        default = "info";
      };

      replicas = mkOption {
        description = mdDoc "Number of replicas";
        type = types.int;
        default = 1;
      };

      useProbes = mkOption {
        description = mdDoc "Enable readiness and liveness probes";
        type = types.bool;
        default = true;
      };
    };

    extraResources = cfg: {
      deployments = {
        ${name} = {
          metadata.labels = {
            "app.kubernetes.io/instance" = name;
            "app.kubernetes.io/name" = name;
            "app.kubernetes.io/version" = "latest";
          };

          spec = {
            replicas = cfg.replicas;
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

                containers = [
                  {
                    inherit name;
                    image = cfg.image;
                    imagePullPolicy = "IfNotPresent";
                    env = [
                      {
                        name = "TZ";
                        value = cfg.tz;
                      }
                      {
                        name = "TUNARR_SERVER_PORT";
                        value = toString cfg.service.port;
                      }
                      {
                        name = "LOG_LEVEL";
                        value = cfg.logLevel;
                      }
                    ];
                    ports = [
                      {
                        containerPort = cfg.service.port;
                        name = "http";
                        protocol = "TCP";
                      }
                    ];
                    readinessProbe = lib.mkIf cfg.useProbes {
                      httpGet = {
                        path = "/";
                        port = cfg.service.port;
                      };
                      initialDelaySeconds = 30;
                      periodSeconds = 10;
                      timeoutSeconds = 5;
                      successThreshold = 1;
                      failureThreshold = 3;
                    };
                    livenessProbe = lib.mkIf cfg.useProbes {
                      httpGet = {
                        path = "/";
                        port = cfg.service.port;
                      };
                      initialDelaySeconds = 60;
                      periodSeconds = 30;
                      timeoutSeconds = 5;
                      successThreshold = 1;
                      failureThreshold = 3;
                    };
                    volumeMounts = [
                      {
                        mountPath = "/config/tunarr";
                        name = "config";
                      }
                    ]
                    ++ (lib.optionals cfg.nfs.enable [
                      {
                        mountPath = "/tv";
                        name = "tv";
                      }
                      {
                        mountPath = "/movies";
                        name = "movies";
                      }
                    ]);
                  }
                ];

                serviceAccountName = "default";

                volumes = [
                  {
                    name = "config";
                    persistentVolumeClaim.claimName = "${name}-${name}-config";
                  }
                ]
                ++ (lib.optionals cfg.nfs.enable [
                  {
                    name = "tv";
                    persistentVolumeClaim.claimName = "${name}-${name}-tv";
                  }
                  {
                    name = "movies";
                    persistentVolumeClaim.claimName = "${name}-${name}-movies";
                  }
                ]);
              };
            };
          };
        };
      };

      ingresses.${name}.spec = with cfg.ingress; {
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

      persistentVolumeClaims = {
        "${name}-${name}-config".spec = {
          inherit (cfg) storageClassName;
          accessModes = [ "ReadWriteOnce" ];
          resources.requests.storage = "5Gi";
        };
      }
      // (lib.optionalAttrs cfg.nfs.enable {
        "${name}-${name}-tv".spec = {
          accessModes = [ "ReadWriteMany" ];
          resources.requests.storage = "1Gi";
          storageClassName = "";
          volumeName = "${name}-${name}-tv-nfs";
        };
        "${name}-${name}-movies".spec = {
          accessModes = [ "ReadWriteMany" ];
          resources.requests.storage = "1Gi";
          storageClassName = "";
          volumeName = "${name}-${name}-movies-nfs";
        };
      });

      services.${name}.spec = {
        ports = [
          {
            name = "http";
            port = cfg.service.port;
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

      # NFS PersistentVolumes for TV and Movies (same paths as arr stack)
      persistentVolumes = lib.optionalAttrs cfg.nfs.enable {
        "${name}-${name}-tv-nfs" = {
          apiVersion = "v1";
          kind = "PersistentVolume";
          metadata = {
            name = "${name}-${name}-tv-nfs";
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
              path = "${cfg.nfs.path}/TV";
            };
            persistentVolumeReclaimPolicy = "Retain";
          };
        };
        "${name}-${name}-movies-nfs" = {
          apiVersion = "v1";
          kind = "PersistentVolume";
          metadata = {
            name = "${name}-${name}-movies-nfs";
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
              path = "${cfg.nfs.path}/Movies";
            };
            persistentVolumeReclaimPolicy = "Retain";
          };
        };
      };
    };
  }
