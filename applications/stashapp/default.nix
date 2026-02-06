{ ageRecipients, config, lib, pkgs, ... }:
with lib;
mkArgoApp { inherit config lib; } rec {
  name = "stashapp";
  uses-ingress = true;

  extraOptions = {
    image = mkOption {
      description = mdDoc "The docker image";
      type = types.str;
      default = "stashapp/stash:latest";
    };

    service.port = mkOption {
      description = mdDoc "The service port";
      type = types.int;
      default = 9999;
    };

    storageClassName = mkOption {
      description = mdDoc "The storage class";
      type = types.str;
      default = "longhorn";
    };

    nfs = {
      enable = mkOption {
        description = mdDoc "Enable NFS for data volume";
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

    enableGPU = mkOption {
      description = mdDoc "Enable shared GPU for hardware encoding (mounts /dev/dri)";
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
              serviceAccountName = "default";
            } // {
              containers = [
                ({
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
                      name = "STASH_STASH_DIR";
                      value = "/data";
                    }
                    {
                      name = "FFMPEG_EXE";
                      value = "/usr/bin/ffmpeg";
                    }
                    {
                      name = "FFPROBE_EXE";
                      value = "/usr/bin/ffprobe";
                    }
                  ];
                  ports = [{
                    containerPort = cfg.service.port;
                    name = "http";
                    protocol = "TCP";
                  }];
                  readinessProbe = {
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
                  livenessProbe = {
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
                      mountPath = "/root/.stash";
                      name = "config";
                    }
                    {
                      mountPath = "/data";
                      name = "data";
                    }
                  ] ++ (lib.optionalAttrs cfg.enableGPU [
                    {
                      mountPath = "/dev/dri";
                      name = "dri";
                    }
                  ]);
                } // (lib.optionalAttrs cfg.enableGPU {
                  securityContext = {
                    privileged = false;
                    capabilities = {
                      add = [ "SYS_ADMIN" ];
                    };
                  };
                }))
              ];
              volumes = [
                {
                  name = "config";
                  persistentVolumeClaim.claimName = "${name}-${name}-config";
                }
                {
                  name = "data";
                  persistentVolumeClaim.claimName = "${name}-${name}-data";
                }
              ] ++ (lib.optionalAttrs cfg.enableGPU [
                {
                  name = "dri";
                  hostPath = {
                    path = "/dev/dri";
                    type = "Directory";
                  };
                }
              ]);
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
      "${name}-${name}-config".spec = {
        inherit (cfg) storageClassName;
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "5Gi";
      };
      "${name}-${name}-data".spec = if cfg.nfs.enable then {
        accessModes = [ "ReadWriteMany" ];
        resources.requests.storage = "1Gi";
        storageClassName = "";
        volumeName = "${name}-${name}-data-nfs";
      } else {
        inherit (cfg) storageClassName;
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "100Gi";
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

    # Create NFS PersistentVolume for data when NFS is enabled
    persistentVolumes = lib.optionalAttrs cfg.nfs.enable {
      "${name}-${name}-data-nfs" = {
        apiVersion = "v1";
        kind = "PersistentVolume";
        metadata = {
          name = "${name}-${name}-data-nfs";
        };
        spec = {
          capacity = {
            storage = "1Ti";
          };
          accessModes = [ "ReadWriteMany" ];
          mountOptions = [ "nolock" "soft" "timeo=30" ];
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
