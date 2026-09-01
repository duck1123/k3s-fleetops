{ ... }:
{
  flake.nixidyApps.booklore =
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
        name = "booklore";
        uses-ingress = true;
        uses-nfs = true;
        uses-database = true;

        sopsSecrets = cfg: {
          "booklore-database-password" = {
            password = cfg.database.password;
          };
        };

        extraOptions = {
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

          uid = mkOption {
            description = mdDoc "The user id";
            type = types.str;
            default = "1000";
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
          };

          persistentVolumeClaims = {
            "${name}-${name}-bookdrop" = {
              metadata.annotations."argocd.argoproj.io/sync-options" = "Replace=true";
              spec = {
                accessModes = [ "ReadWriteOnce" ];
                resources.requests.storage = "5Gi";
                storageClassName = "";
                volumeName = "${name}-bookdrop-pv";
              };
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
            "${name}-${name}-data" = {
              metadata.annotations."argocd.argoproj.io/sync-options" = "Replace=true";
              spec = {
                accessModes = [ "ReadWriteOnce" ];
                resources.requests.storage = "5Gi";
                storageClassName = "";
                volumeName = "${name}-data-pv";
              };
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

          persistentVolumes =
            (lib.optionalAttrs cfg.nfs.enable {
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
                    "noexec"
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
            })
            // {
              # Pinned to the specific pre-existing Longhorn volumes (captured
              # via `kubectl get pv`) so that disabling/re-enabling this app
              # rebinds to the same data instead of dynamic provisioning
              # handing back an empty volume. The PV object itself is free to
              # be deleted and recreated by ArgoCD on every enable cycle --
              # only the volumeHandle (the actual Longhorn volume identity)
              # must never change.
              "${name}-data-pv" = {
                apiVersion = "v1";
                kind = "PersistentVolume";
                metadata = {
                  name = "${name}-data-pv";
                  annotations."argocd.argoproj.io/sync-options" = "Replace=true";
                };
                spec = {
                  capacity.storage = "5Gi";
                  accessModes = [ "ReadWriteOnce" ];
                  persistentVolumeReclaimPolicy = "Retain";
                  storageClassName = "";
                  csi = {
                    driver = "driver.longhorn.io";
                    fsType = "ext4";
                    volumeHandle = "pvc-da71c5a0-68e9-48f0-a8a2-e71d5a8adccc";
                    volumeAttributes = {
                      numberOfReplicas = "1";
                      staleReplicaTimeout = "30";
                      fromBackup = "";
                      fsType = "ext4";
                      dataLocality = "disabled";
                      unmapMarkSnapChainRemoved = "ignored";
                      disableRevisionCounter = "true";
                      dataEngine = "v1";
                      backupTargetName = "default";
                    };
                  };
                };
              };
              "${name}-bookdrop-pv" = {
                apiVersion = "v1";
                kind = "PersistentVolume";
                metadata = {
                  name = "${name}-bookdrop-pv";
                  annotations."argocd.argoproj.io/sync-options" = "Replace=true";
                };
                spec = {
                  capacity.storage = "5Gi";
                  accessModes = [ "ReadWriteOnce" ];
                  persistentVolumeReclaimPolicy = "Retain";
                  storageClassName = "";
                  csi = {
                    driver = "driver.longhorn.io";
                    fsType = "ext4";
                    volumeHandle = "pvc-b8bc2a4f-b836-4142-a5cf-c513c51f5422";
                    volumeAttributes = {
                      numberOfReplicas = "1";
                      staleReplicaTimeout = "30";
                      fromBackup = "";
                      fsType = "ext4";
                      dataLocality = "disabled";
                      unmapMarkSnapChainRemoved = "ignored";
                      disableRevisionCounter = "true";
                      dataEngine = "v1";
                      backupTargetName = "default";
                    };
                  };
                };
              };
            };
        };
      };
}
