{
  config,
  lib,
  self,
  ...
}:
with lib;
self.lib.mkArgoApp { inherit config lib; } rec {
  name = "home-assistant";
  uses-ingress = true;

  extraOptions = {
    image = mkOption {
      description = mdDoc "Home Assistant container image (pin a version tag for reproducible deploys)";
      type = types.str;
      default = "ghcr.io/home-assistant/home-assistant:stable";
    };

    timezone = mkOption {
      description = mdDoc "Container TZ (e.g. America/New_York)";
      type = types.str;
      default = "Etc/UTC";
    };

    storageClassName = mkOption {
      description = mdDoc "Storage class for the /config volume";
      type = types.str;
      default = "longhorn";
    };

    configSize = mkOption {
      description = mdDoc "PVC size for Home Assistant configuration and state";
      type = types.str;
      default = "10Gi";
    };
  };

  extraResources = cfg: {
    deployments.${name} = {
      metadata.labels = {
        "app.kubernetes.io/instance" = name;
        "app.kubernetes.io/name" = name;
      };

      spec = {
        replicas = 1;
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
                    value = cfg.timezone;
                  }
                ];

                ports = [
                  {
                    containerPort = 8123;
                    name = "http";
                    protocol = "TCP";
                  }
                ];

                livenessProbe = {
                  httpGet = {
                    path = "/";
                    port = "http";
                  };
                  initialDelaySeconds = 120;
                  periodSeconds = 30;
                  timeoutSeconds = 10;
                  failureThreshold = 5;
                };

                readinessProbe = {
                  httpGet = {
                    path = "/";
                    port = "http";
                  };
                  initialDelaySeconds = 60;
                  periodSeconds = 15;
                  timeoutSeconds = 10;
                  failureThreshold = 6;
                };

                volumeMounts = [
                  {
                    mountPath = "/config";
                    name = "config";
                  }
                ];
              }
            ];

            volumes = [
              {
                name = "config";
                persistentVolumeClaim.claimName = "${name}-${name}-config";
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

    persistentVolumeClaims."${name}-${name}-config".spec = {
      accessModes = [ "ReadWriteOnce" ];
      resources.requests.storage = cfg.configSize;
      storageClassName = cfg.storageClassName;
    };

    services.${name}.spec = {
      ports = [
        {
          name = "http";
          port = 8123;
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
}
