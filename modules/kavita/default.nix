{ config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } rec {
  name = "kavita";
  uses-ingress = true;

  extraOptions = {
    storageClassName = mkOption {
      description = mdDoc "Storage class name for Kavita persistence";
      type = types.str;
      default = "longhorn";
    };
  };

  extraResources = cfg: {
    deployments.kavita = {
      metadata = {
        # inherit name;

        labels = {
          "app.kubernetes.io/instance" = name;
          "app.kubernetes.io/name" = name;
          "app.kubernetes.io/version" = "0.8.7";
        };
      };
      spec = {
        selector.matchLabels = {
          "app.kubernetes.io/instance" = name;
          "app.kubernetes.io/name" = name;
        };

        template = {
          metadata = {
            labels = {
              "app.kubernetes.io/instance" = name;
              "app.kubernetes.io/name" = name;
              # "app.kubernetes.io/version" = "0.8.7";
            };
          };

          spec = {
            automountServiceAccountToken = true;
            serviceAccountName = "default";
            containers = [{
              inherit name;
              image = "linuxserver/kavita:0.8.7";
              imagePullPolicy = "IfNotPresent";
              env = [
                {
                  name = "PGID";
                  value = "1000";
                }
                {
                  name = "PUID";
                  value = "1000";
                }
                {
                  name = "TZ";
                  value = "Etc/UTC";
                }
              ];

              livenessProbe = {
                failureThreshold = 3;
                initialDelaySeconds = 0;
                periodSeconds = 10;
                tcpSocket.port = 5000;
              };

              ports = [{
                containerPort = 5000;
                name = "http";
                protocol = "TCP";
              }];

              volumeMounts = [
                {
                  mountPath = "/books";
                  name = "books";
                }
                {
                  mountPath = "/config";
                  name = "config";
                }
              ];
            }];
            volumes = [
              {
                name = "books";
                persistentVolumeClaim.claimName = "${name}-${name}-books";
              }
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
    };

    persistentVolumeClaims = {
      "${name}-${name}-books".spec = {
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "5Gi";
        storageClassName = cfg.storageClassName;
      };
      "${name}-${name}-config".spec = {
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "5Gi";
        storageClassName = cfg.storageClassName;
      };
    };

    services.${name}.spec = {
      ports = [{
        name = "http";
        port = 5000;
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
