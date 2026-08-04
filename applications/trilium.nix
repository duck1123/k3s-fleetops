{ ... }:
{
  flake.nixidyApps.trilium =
    {
      config,
      lib,
      self,
      ...
    }:
    with lib;
    self.lib.mkArgoApp { inherit config lib; } rec {
      name = "trilium";
      uses-ingress = true;

      extraOptions = {
        image = mkOption {
          description = mdDoc "The docker image";
          type = types.str;
          default = "triliumnext/trilium:v0.104.1";
        };

        service.port = mkOption {
          description = mdDoc "The service port";
          type = types.int;
          default = 8080;
        };

        dataStorage = mkOption {
          description = mdDoc "Size of the data PVC";
          type = types.str;
          default = "10Gi";
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
          };

          spec = {
            replicas = cfg.replicas;
            strategy.type = "Recreate";
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
                      tcpSocket.port = cfg.service.port;
                      initialDelaySeconds = 15;
                      periodSeconds = 10;
                      timeoutSeconds = 5;
                      successThreshold = 1;
                      failureThreshold = 3;
                    };
                    livenessProbe = {
                      tcpSocket.port = cfg.service.port;
                      initialDelaySeconds = 30;
                      periodSeconds = 30;
                      timeoutSeconds = 5;
                      successThreshold = 1;
                      failureThreshold = 3;
                    };
                    volumeMounts = [
                      {
                        mountPath = "/home/node/trilium-data";
                        name = "data";
                      }
                    ];
                  }
                ];

                volumes = [
                  {
                    name = "data";
                    persistentVolumeClaim.claimName = "${name}-${name}-data";
                  }
                ];
              };
            };
          };
        };

        ingresses.${name} = with cfg.ingress; {
          metadata.annotations."cert-manager.io/cluster-issuer" = clusterIssuer;
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
                    pathType = "ImplementationSpecific";
                  }
                ];
              }
            ];

            tls = [
              {
                hosts = [ domain ];
                secretName = "${name}-tls";
              }
            ];
          };
        };

        persistentVolumeClaims = {
          "${name}-${name}-data".spec = {
            inherit (cfg) storageClassName;
            accessModes = [ "ReadWriteOnce" ];
            resources.requests.storage = cfg.dataStorage;
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
      };
    };
}
