{ ... }:
{
  flake.nixidyApps.fileflows =
    {
      config,
      lib,
      self,
      ...
    }:
    with lib;
    self.lib.mkArgoApp { inherit config lib; } rec {
      name = "fileflows";
      uses-ingress = true;

      extraOptions = {
        image = mkOption {
          description = mdDoc "The docker image";
          type = types.str;
          default = "revenz/fileflows:latest";
        };

        service.port = mkOption {
          description = mdDoc "The web UI service port";
          type = types.int;
          default = 5000;
        };

        pgid = mkOption {
          description = mdDoc "The group ID";
          type = types.int;
          default = 1000;
        };

        puid = mkOption {
          description = mdDoc "The user ID";
          type = types.int;
          default = 1000;
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

        nfs = {
          enable = mkOption {
            description = mdDoc "Enable NFS for media and temp volumes";
            type = types.bool;
            default = false;
          };

          server = mkOption {
            description = mdDoc "NFS server hostname/IP";
            type = types.str;
            default = "nasnix";
          };

          path = mkOption {
            description = mdDoc "NFS server base path";
            type = types.str;
            default = "/mnt/media";
          };
        };

        enableGPU = mkOption {
          description = mdDoc "Enable GPU for hardware transcoding (mounts /dev/dri for Intel/AMD iGPU)";
          type = types.bool;
          default = false;
        };

        # GID of the host's 'render' group for /dev/dri access. Run 'getent group render' on the node (e.g. 303 on NixOS).
        renderGroupGID = mkOption {
          description = mdDoc "GID of the host render group for /dev/dri device access when enableGPU is true.";
          type = types.int;
          default = 303;
        };

        # Intel: "iris" (8th gen+) or "i965" (older). AMD: "radeonsi".
        libvaDriverName = mkOption {
          description = mdDoc "LIBVA_DRIVER_NAME for VAAPI (e.g. iris for modern Intel, i965 for older Intel). Empty string = do not set.";
          type = types.str;
          default = "";
        };

        # Use a specific DRI render node when the GPU is not at the default renderD128 path.
        vaapiRenderDevice = mkOption {
          description = mdDoc "Host DRI render device name (e.g. renderD129) to mount as /dev/dri/renderD128. Empty = mount entire /dev/dri.";
          type = types.str;
          default = "";
        };

        ingress.annotations = mkOption {
          description = mdDoc "Annotations for the Ingress resource";
          type = types.attrsOf types.str;
          default = { };
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
                  securityContext = {
                    fsGroup = cfg.pgid;
                    fsGroupChangePolicy = "OnRootMismatch";
                    runAsUser = if cfg.enableGPU then 0 else cfg.puid;
                    runAsGroup = if cfg.enableGPU then 0 else cfg.pgid;
                    supplementalGroups = lib.optionals cfg.enableGPU [ cfg.renderGroupGID ];
                  };

                  containers = [
                    {
                      inherit name;
                      image = cfg.image;
                      imagePullPolicy = "IfNotPresent";
                      env = [
                        {
                          name = "PGID";
                          value = "${toString cfg.pgid}";
                        }
                        {
                          name = "PUID";
                          value = "${toString cfg.puid}";
                        }
                        {
                          name = "TZ";
                          value = cfg.tz;
                        }
                        {
                          name = "FFMPEG_VAAPI";
                          value = if cfg.enableGPU then "1" else "0";
                        }
                      ]
                      ++ (lib.optionals (cfg.libvaDriverName != "") [
                        {
                          name = "LIBVA_DRIVER_NAME";
                          value = cfg.libvaDriverName;
                        }
                      ])
                      ++ (lib.optionals cfg.enableGPU [
                        {
                          name = "XDG_RUNTIME_DIR";
                          value = "";
                        }
                        {
                          name = "LIBVA_DRIVERS_PATH";
                          value = "/usr/lib/x86_64-linux-gnu/dri";
                        }
                        {
                          name = "LIBVA_MESSAGING";
                          value = "1";
                        }
                      ]);

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
                        initialDelaySeconds = 60;
                        periodSeconds = 15;
                        timeoutSeconds = 10;
                        successThreshold = 1;
                        failureThreshold = 6;
                      };

                      livenessProbe = lib.mkIf cfg.useProbes {
                        httpGet = {
                          path = "/";
                          port = cfg.service.port;
                        };
                        initialDelaySeconds = 120;
                        periodSeconds = 30;
                        timeoutSeconds = 10;
                        successThreshold = 1;
                        failureThreshold = 3;
                      };

                      volumeMounts = [
                        {
                          mountPath = "/app/Data";
                          name = "config";
                        }
                        {
                          mountPath = "/temp";
                          name = "temp";
                        }
                        {
                          mountPath = "/media";
                          name = "media";
                        }
                      ]
                      ++ (lib.optionals cfg.enableGPU (
                        if cfg.vaapiRenderDevice != "" then
                          [
                            {
                              mountPath = "/dev/dri/renderD128";
                              name = "dri";
                            }
                          ]
                        else
                          [
                            {
                              mountPath = "/dev/dri";
                              name = "dri";
                            }
                          ]
                      ));

                      securityContext = lib.optionalAttrs cfg.enableGPU {
                        capabilities.add = [ "SYS_ADMIN" ];
                        privileged = true;
                      };
                    }
                  ];

                  serviceAccountName = "default";

                  volumes = [
                    {
                      name = "config";
                      persistentVolumeClaim.claimName = "${name}-${name}-config";
                    }
                    {
                      name = "temp";
                      persistentVolumeClaim.claimName = "${name}-${name}-temp";
                    }
                    {
                      name = "media";
                      persistentVolumeClaim.claimName = "${name}-${name}-media";
                    }
                  ]
                  ++ (lib.optionals cfg.enableGPU (
                    if cfg.vaapiRenderDevice != "" then
                      [
                        {
                          name = "dri";
                          hostPath = {
                            path = "/dev/dri/${cfg.vaapiRenderDevice}";
                            type = "CharDevice";
                          };
                        }
                      ]
                    else
                      [
                        {
                          name = "dri";
                          hostPath = {
                            path = "/dev/dri";
                            type = "Directory";
                          };
                        }
                      ]
                  ));
                };
              };
            };
          };
        };

        ingresses.${name} = with cfg.ingress; {
          metadata = lib.optionalAttrs (annotations != { }) { inherit annotations; };
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
                    pathType = "Prefix";
                  }
                ];
              }
            ];

            tls = [ { hosts = [ domain ]; } ];
          };
        };

        persistentVolumeClaims = {
          "${name}-${name}-config".spec = {
            inherit (cfg) storageClassName;
            accessModes = [ "ReadWriteOnce" ];
            resources.requests.storage = "5Gi";
          };
          "${name}-${name}-temp".spec =
            if cfg.nfs.enable then
              {
                accessModes = [ "ReadWriteMany" ];
                resources.requests.storage = "1Gi";
                storageClassName = "";
                volumeName = "${name}-${name}-temp-nfs";
              }
            else
              {
                inherit (cfg) storageClassName;
                accessModes = [ "ReadWriteOnce" ];
                resources.requests.storage = "50Gi";
              };
          "${name}-${name}-media".spec =
            if cfg.nfs.enable then
              {
                accessModes = [ "ReadWriteMany" ];
                resources.requests.storage = "1Gi";
                storageClassName = "";
                volumeName = "${name}-${name}-media-nfs";
              }
            else
              {
                inherit (cfg) storageClassName;
                accessModes = [ "ReadWriteOnce" ];
                resources.requests.storage = "100Gi";
              };
        };

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

        persistentVolumes = lib.optionalAttrs cfg.nfs.enable {
          "${name}-${name}-temp-nfs" = {
            apiVersion = "v1";
            kind = "PersistentVolume";
            metadata.name = "${name}-${name}-temp-nfs";
            spec = {
              capacity.storage = "1Ti";
              accessModes = [ "ReadWriteMany" ];
              mountOptions = [
                "nolock"
                "soft"
                "timeo=30"
              ];
              nfs = {
                server = cfg.nfs.server;
                path = "${cfg.nfs.path}/fileflows-temp";
              };
              persistentVolumeReclaimPolicy = "Retain";
            };
          };
          "${name}-${name}-media-nfs" = {
            apiVersion = "v1";
            kind = "PersistentVolume";
            metadata.name = "${name}-${name}-media-nfs";
            spec = {
              capacity.storage = "1Ti";
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
      };
    };
}
