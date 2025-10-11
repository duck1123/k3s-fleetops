{ config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } rec {
  name = "booklore";
  uses-ingress = true;

  extraOptions = {

    image = mkOption {
      description = mdDoc "The docker image";
      type = types.str;
      default = "booklore/booklore:latest";
    };

    service = {
      port = mkOption {
        description = mdDoc "The service port";
        type = types.int;
        default = 6060;
      };
    };

    storageClassName = mkOption {
      description = mdDoc "The storage class";
      type = types.str;
      default = "longhorn";
    };

    gid = mkOption {
      description = mdDoc "The group id";
      type = types.str;
      default = "1000";
    };

    tz = mkOption {
      description = mdDoc "The timezone";
      type = types.str;
      default = "Etc/UTC";
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
              containers = [{
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
                    value = "jdbc:mariadb://mariadb:3306/booklore";
                  }
                  {
                    name = "DATABASE_USERNAME";
                    value = "booklore";
                  }
                  {
                    name = "DATABASE_PASSWORD";
                    valueFrom.secretKeyRef = {
                      name = "mariadb-password";
                      key = "password";
                    };
                  }
                  # {
                  #   name = "BOOKLORE_PORT";
                  #   value = "${cfg.service.port}";
                  # }
                  {
                    name = "SWAGGER_ENABLED";
                    value = "false";
                  }
                ];

                livenessProbe = {
                  failureThreshold = 3;
                  initialDelaySeconds = 0;
                  periodSeconds = 10;
                  tcpSocket.port = 5000;
                };

                ports = [{
                  containerPort = cfg.service.port;
                  name = "http";
                  protocol = "TCP";
                }];

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
              }];
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
      "${name}-${name}-bookdrop".spec = {
        inherit (cfg) storageClassName;
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "5Gi";
      };
      "${name}-${name}-books".spec = {
        inherit (cfg) storageClassName;
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "5Gi";
      };
      "${name}-${name}-data".spec = {
        inherit (cfg) storageClassName;
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "5Gi";
      };
    };

    services = {
      ${name}.spec = {
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

  };
}
