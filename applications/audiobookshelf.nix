{ ... }:
{
  flake.nixidyApps.audiobookshelf =
    {
      config,
      lib,
      self,
      ...
    }:
    with lib;
    self.lib.mkArgoApp { inherit config lib; } rec {
      name = "audiobookshelf";
      uses-ingress = true;

      extraOptions = {
        image = mkOption {
          description = mdDoc "The docker image";
          type = types.str;
          default = "ghcr.io/advplyr/audiobookshelf:latest";
        };

        service.port = mkOption {
          description = mdDoc "The service port";
          type = types.int;
          default = 80;
        };

        nfs = {
          enable = mkOption {
            description = mdDoc "Enable NFS for audiobooks volume";
            type = types.bool;
            default = false;
          };

          server = mkOption {
            description = mdDoc "NFS server hostname/IP";
            type = types.str;
            default = "nasnix";
          };

          path = mkOption {
            description = mdDoc "NFS server path to Audiobooks share";
            type = types.str;
            default = "/mnt/Audiobooks";
          };
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
      };

      extraResources = cfg: {
        deployments.${name} = {
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

                containers = [
                  {
                    inherit name;
                    image = cfg.image;
                    imagePullPolicy = "IfNotPresent";
                    env = [
                      {
                        name = "PGID";
                        value = toString cfg.pgid;
                      }
                      {
                        name = "PUID";
                        value = toString cfg.puid;
                      }
                      {
                        name = "TZ";
                        value = cfg.tz;
                      }
                    ];
                    ports = [
                      {
                        containerPort = cfg.service.port;
                        name = "http";
                        protocol = "TCP";
                      }
                    ];
                    readinessProbe = {
                      httpGet = {
                        path = "/healthcheck";
                        port = cfg.service.port;
                      };
                      initialDelaySeconds = 15;
                      periodSeconds = 10;
                      timeoutSeconds = 5;
                      successThreshold = 1;
                      failureThreshold = 3;
                    };
                    livenessProbe = {
                      httpGet = {
                        path = "/healthcheck";
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
                        mountPath = "/metadata";
                        name = "metadata";
                      }
                      {
                        mountPath = "/audiobooks";
                        name = "audiobooks";
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
                    name = "metadata";
                    persistentVolumeClaim.claimName = "${name}-${name}-metadata";
                  }
                  {
                    name = "audiobooks";
                    persistentVolumeClaim.claimName = "${name}-${name}-audiobooks";
                  }
                ];
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
            resources.requests.storage = "1Gi";
          };
          "${name}-${name}-metadata".spec = {
            inherit (cfg) storageClassName;
            accessModes = [ "ReadWriteOnce" ];
            resources.requests.storage = "5Gi";
          };
          "${name}-${name}-audiobooks".spec =
            if cfg.nfs.enable then
              {
                accessModes = [ "ReadWriteMany" ];
                resources.requests.storage = "1Gi";
                storageClassName = "";
                volumeName = "${name}-${name}-audiobooks-nfs";
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
          "${name}-${name}-audiobooks-nfs" = {
            apiVersion = "v1";
            kind = "PersistentVolume";
            metadata = {
              name = "${name}-${name}-audiobooks-nfs";
            };
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
