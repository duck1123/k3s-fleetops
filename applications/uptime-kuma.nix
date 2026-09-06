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
    self.lib.mkArgoApp { inherit config lib self; } rec {
      name = "uptime-kuma";
      uses-ingress = true;

      extraOptions = {
        image = mkOption {
          description = mdDoc "The docker image";
          type = types.str;
          default = "louislam/uptime-kuma:2.5.0";
        };

        service.port = mkOption {
          description = mdDoc "The service port";
          type = types.int;
          default = 3001;
        };
      };

      extraResources =
        cfg:
        let
          pinnedData = self.lib.mkPinnedVolume {
            pvcName = "${name}-${name}-data";
            volumeHandle = "pvc-1d098edf-77ca-4e22-9742-312c090598b5";
            size = "5Gi";
          };
        in
        {
          deployments.${name} = {
            metadata.labels = {
              "app.kubernetes.io/instance" = name;
              "app.kubernetes.io/name" = name;
            };

            spec = {
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

                      ports = [
                        {
                          containerPort = cfg.service.port;
                          name = "http";
                          protocol = "TCP";
                        }
                      ];

                      livenessProbe = {
                        failureThreshold = 60;
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

          persistentVolumeClaims = pinnedData.persistentVolumeClaims;
          persistentVolumes = pinnedData.persistentVolumes;

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
