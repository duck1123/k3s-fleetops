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

      enableGPU = mkOption {
        description = mdDoc "Enable GPU for hardware transcoding (mounts /dev/dri for AMD/Intel VAAPI)";
        type = types.bool;
        default = false;
      };

      # GID of the host's 'render' group for /dev/dri access (AMD/Intel VAAPI).
      renderGroupGID = mkOption {
        description = mdDoc "GID of the host render group for /dev/dri when enableGPU is true. Run 'getent group render' on the node (e.g. 303 on NixOS).";
        type = types.int;
        default = 303;
      };

      # Use a specific DRI render node (e.g. renderD129) as /dev/dri/renderD128 in the container. Set when your GPU is the second card on the node. Empty = mount whole /dev/dri.
      vaapiRenderDevice = mkOption {
        description = mdDoc "Host DRI render device name (e.g. renderD129) to mount as /dev/dri/renderD128 when enableGPU is true. Empty = mount entire /dev/dri.";
        type = types.str;
        default = "";
      };

      # Set to true once to clear corrupted SQLite DB (e.g. "database disk image is malformed"); Tunarr will start fresh. Set back to false after the pod has started.
      resetDatabase = mkOption {
        description = mdDoc "If true, clear /config/tunarr before startup so Tunarr creates a new DB. Use once to recover from corruption, then set back to false.";
        type = types.bool;
        default = false;
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
                # Ensure config volume is writable: root when using GPU, else GID 1000 for typical app user.
                securityContext = if cfg.enableGPU then {
                  runAsUser = 0;
                  runAsGroup = 0;
                  supplementalGroups = [ cfg.renderGroupGID ];
                  fsGroup = 0;
                } else {
                  fsGroup = 1000;
                };

                containers = [
                  {
                    inherit name;
                    image = cfg.image;
                    imagePullPolicy = "IfNotPresent";
                    # Raise nofile limit so embedded Meilisearch doesn't hit EAGAIN (os error 11) during indexing.
                    command = [ "sh" "-c" "ulimit -n 65536 && exec /tunarr/tunarr" ];
                    args = [ ];
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
                        readOnly = false;
                      }
                      # Writable /tmp for SQLite temp files and Meilisearch; avoids EROFS during library scans.
                      {
                        mountPath = "/tmp";
                        name = "tmp";
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
                    ])
                    ++ (lib.optionals cfg.enableGPU (
                      if cfg.vaapiRenderDevice != "" then
                        [{
                          mountPath = "/dev/dri/renderD128";
                          name = "dri";
                        }]
                      else
                        [{
                          mountPath = "/dev/dri";
                          name = "dri";
                        }]
                    ));
                    # Force writable root and config; image may default readOnlyRootFilesystem which can make mounts appear read-only on some runtimes.
                    securityContext = {
                      readOnlyRootFilesystem = false;
                    } // lib.optionalAttrs cfg.enableGPU {
                      capabilities.add = [ "SYS_ADMIN" ];
                      privileged = true;
                    };
                  }
                ];

                initContainers = (lib.optionals cfg.resetDatabase [
                  {
                    name = "config-reset";
                    image = "busybox:latest";
                    imagePullPolicy = "IfNotPresent";
                    command = [
                      "sh"
                      "-c"
                      "rm -rf /config/tunarr/*"
                    ];
                    securityContext.runAsUser = 0;
                    volumeMounts = [
                      {
                        mountPath = "/config/tunarr";
                        name = "config";
                      }
                    ];
                  }
                ]) ++ [
                  {
                    name = "config-permissions";
                    image = "busybox:latest";
                    imagePullPolicy = "IfNotPresent";
                    command = [
                      "sh"
                      "-c"
                      "chown -R 0:0 /config/tunarr && chmod -R 1777 /config/tunarr && touch /config/tunarr/.write-test && rm -f /config/tunarr/.write-test"
                    ];
                    securityContext.runAsUser = 0;
                    volumeMounts = [
                      {
                        mountPath = "/config/tunarr";
                        name = "config";
                        readOnly = false;
                      }
                    ];
                  }
                ];

                serviceAccountName = "default";

                volumes = [
                  {
                    name = "config";
                    persistentVolumeClaim.claimName = "${name}-${name}-config";
                  }
                  {
                    name = "tmp";
                    emptyDir = { };
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
                ])
                ++ (lib.optionals cfg.enableGPU (
                  if cfg.vaapiRenderDevice != "" then
                    [{
                      name = "dri";
                      hostPath = {
                        path = "/dev/dri/${cfg.vaapiRenderDevice}";
                        type = "CharDevice";
                      };
                    }]
                  else
                    [{
                      name = "dri";
                      hostPath = {
                        path = "/dev/dri";
                        type = "Directory";
                      };
                    }]
                ));
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
