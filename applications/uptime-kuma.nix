{ ... }:
{
  flake.nixidyApps.uptime-kuma =
    {
      config,
      lib,
      self,
      ...
    }:
    with lib;
    self.lib.mkArgoApp { inherit config lib; } rec {
      name = "uptime-kuma";
      uses-ingress = true;

      extraOptions = {
        image = mkOption {
          description = mdDoc "The docker image";
          type = types.str;
          default = "louislam/uptime-kuma:1";
        };

        service.port = mkOption {
          description = mdDoc "The service port";
          type = types.int;
          default = 3001;
        };
      };

      extraResources = cfg: {
        deployments.${name} = {
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

                    ports = [
                      {
                        containerPort = cfg.service.port;
                        name = "http";
                        protocol = "TCP";
                      }
                    ];

                    livenessProbe = {
                      failureThreshold = 3;
                      initialDelaySeconds = 30;
                      periodSeconds = 10;
                      tcpSocket.port = cfg.service.port;
                    };

                    readinessProbe = {
                      failureThreshold = 3;
                      initialDelaySeconds = 10;
                      periodSeconds = 10;
                      tcpSocket.port = cfg.service.port;
                    };

                    volumeMounts = [
                      {
                        mountPath = "/app/data";
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
            tls = [ { hosts = [ domain ]; } ];
          };
        };

        persistentVolumeClaims."${name}-${name}-data".spec = {
          accessModes = [ "ReadWriteOnce" ];
          resources.requests.storage = "5Gi";
          storageClassName = cfg.storageClassName;
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
