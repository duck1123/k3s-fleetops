{ ageRecipients, config, lib, pkgs, ... }:
with lib;
mkArgoApp { inherit config lib; } rec {
  name = "lidarr";
  uses-ingress = true;

  extraOptions = {
    image = mkOption {
      description = mdDoc "The docker image";
      type = types.str;
      default = "linuxserver/lidarr:latest";
    };

    service.port = mkOption {
      description = mdDoc "The service port";
      type = types.int;
      default = 8686;
    };

    storageClassName = mkOption {
      description = mdDoc "The storage class";
      type = types.str;
      default = "longhorn";
    };

    vpn = {
      enable = mkOption {
        description = mdDoc "Enable VPN routing through shared gluetun service";
        type = types.bool;
        default = true;
      };

      sharedGluetunService = mkOption {
        description = mdDoc "Service name for shared gluetun (e.g., gluetun.gluetun)";
        type = types.str;
        default = "gluetun.gluetun";
      };
    };

    nfs = {
      enable = mkOption {
        description = mdDoc "Enable NFS for downloads volume";
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
                  ] ++ (lib.optionalAttrs cfg.vpn.enable [
                    # Configure Lidarr to use shared gluetun's HTTP proxy
                    {
                      name = "HTTP_PROXY";
                      value = "http://${cfg.vpn.sharedGluetunService}:8888";
                    }
                    {
                      name = "HTTPS_PROXY";
                      value = "http://${cfg.vpn.sharedGluetunService}:8888";
                    }
                    {
                      name = "NO_PROXY";
                      value = "localhost,127.0.0.1,.svc,.svc.cluster.local";
                    }
                  ]);
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
                    initialDelaySeconds = 10;
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
                    initialDelaySeconds = 30;
                    periodSeconds = 30;
                    timeoutSeconds = 5;
                    successThreshold = 1;
                    failureThreshold = 3;
                  };
                  volumeMounts = [
                    {
                      mountPath = "/config";
                      name = "config";
                    }
                    {
                      mountPath = "/downloads";
                      name = "downloads";
                    }
                    {
                      mountPath = "/music";
                      name = "music";
                    }
                  ];
                }
              ];
              volumes = [
                {
                  name = "config";
                  persistentVolumeClaim.claimName = "${name}-${name}-config";
                }
                {
                  name = "downloads";
                  persistentVolumeClaim.claimName = "${name}-${name}-downloads";
                }
                {
                  name = "music";
                  persistentVolumeClaim.claimName = "${name}-${name}-music";
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

    persistentVolumes = lib.optionalAttrs (cfg.nfs.enable) {
      "${name}-${name}-downloads-nfs" = {
        apiVersion = "v1";
        metadata.name = "${name}-${name}-downloads-nfs";
        spec = {
          accessModes = [ "ReadWriteMany" ];
          capacity.storage = "1Ti";
          nfs = {
            server = cfg.nfs.server;
            path = "${cfg.nfs.path}/Downloads";
          };
          persistentVolumeReclaimPolicy = "Retain";
        };
      };
      "${name}-${name}-music-nfs" = {
        apiVersion = "v1";
        metadata.name = "${name}-${name}-music-nfs";
        spec = {
          capacity = { storage = "1Ti"; };
          accessModes = [ "ReadWriteMany" ];
          nfs = {
            server = cfg.nfs.server;
            path = "${cfg.nfs.path}/Music";
          };
          persistentVolumeReclaimPolicy = "Retain";
        };
      };
    };

    persistentVolumeClaims = {
      "${name}-${name}-config".spec = {
        inherit (cfg) storageClassName;
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "5Gi";
      };
      "${name}-${name}-downloads".spec = if cfg.nfs.enable then {
        accessModes = [ "ReadWriteMany" ];
        resources.requests.storage = "1Gi";
        storageClassName = "";
        volumeName = "${name}-${name}-downloads-nfs";
      } else {
        inherit (cfg) storageClassName;
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "50Gi";
      };
      "${name}-${name}-music".spec = if cfg.nfs.enable then {
        accessModes = [ "ReadWriteMany" ];
        resources.requests.storage = "1Gi";
        storageClassName = "";
        volumeName = "${name}-${name}-music-nfs";
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

  };
}
