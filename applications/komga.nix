{ ... }:
{
  flake.nixidyApps.komga =
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
        name = "komga";
        uses-ingress = true;

        extraOptions = {
          gid = mkOption {
            description = mdDoc "The group id";
            type = types.str;
            default = "1000";
          };

          image = mkOption {
            description = mdDoc "The docker image";
            type = types.str;
            default = "gotson/komga:latest";
          };

          service.port = mkOption {
            description = mdDoc "The service port";
            type = types.int;
            default = 25600;
          };

          nfs = {
            enable = mkOption {
              description = mdDoc "Enable NFS for data volume";
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
              default = "/mnt/comics";
            };
          };

          uid = mkOption {
            description = mdDoc "The user id";
            type = types.str;
            default = "1000";
          };

        };

        extraResources = cfg: {
          deployments = {
            komga = {
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
                    containers = [
                      {
                        inherit name;
                        image = cfg.image;
                        imagePullPolicy = "IfNotPresent";
                        env = [
                          {
                            name = "PUID";
                            value = cfg.uid;
                          }
                          {
                            name = "PGID";
                            value = cfg.gid;
                          }
                          {
                            name = "TZ";
                            value = cfg.tz;
                          }
                          {
                            name = "SERVER_PORT";
                            value = "${toString cfg.service.port}";
                          }
                        ];

                        livenessProbe = {
                          failureThreshold = 3;
                          initialDelaySeconds = 30;
                          periodSeconds = 10;
                          tcpSocket.port = cfg.service.port;
                        };

                        ports = [
                          {
                            containerPort = cfg.service.port;
                            name = "http";
                            protocol = "TCP";
                          }
                        ];

                        volumeMounts = [
                          {
                            mountPath = "/config";
                            name = "config";
                          }
                          {
                            mountPath = "/data";
                            name = "data";
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
          };

          persistentVolumeClaims = {
            "${name}-${name}-config".spec = {
              inherit (cfg) storageClassName;
              accessModes = [ "ReadWriteOnce" ];
              resources.requests.storage = "5Gi";
            };
            "${name}-${name}-data".spec =
              if cfg.nfs.enable then
                {
                  accessModes = [ "ReadWriteMany" ];
                  resources.requests.storage = "1Gi";
                  storageClassName = "";
                  volumeName = "${name}-${name}-data-nfs";
                }
              else
                {
                  inherit (cfg) storageClassName;
                  accessModes = [ "ReadWriteOnce" ];
                  resources.requests.storage = "50Gi";
                };
          };

          services = {
            ${name}.spec = {
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
          };

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
