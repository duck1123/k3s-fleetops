{ config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } rec {
  name = "specter";
  uses-ingress = true;

  extraOptions = {
    imageVersion = mkOption {
      description = mdDoc "The version of bitcoind to deploy";
      type = types.str;
      default = "v2.1.1";
    };
    user-env = mkOption {
      description = mdDoc "The name of the user";
      type = types.str;
      default = "satoshi";
    };
  };

  defaultValues = cfg:
    with cfg; {
      image.tag = imageVersion;

      ingress = with ingress; {
        enabled = true;
        hosts = [{
          host = domain;
          paths = [{ path = "/"; }];
        }];
        tls = [{
          secretName = "specter-prod-tls";
          hosts = [ domain ];
        }];
      };

      persistence.storageClassName = "local-path";

      nodeConfig = builtins.toJSON rec {
        alias = "default";
        autodetect = false;
        datadir = "";
        external_node = true;
        fullpath = "/data/.specter/nodes/${alias}.json";
        host = "${alias}-bitcoin";
        name = alias;
        protocol = "http";
        # TODO: generate a better password
        password = "rpcpassword";
        port = 18443;
        user = "rpcuser";
      };
    };

  extraResources = cfg:
    let instance-name = name;
    in {
      deployments = {
        specter = {
          metadata.labels = {
            "app.kubernetes.io/instance" = instance-name;
            "app.kubernetes.io/name" = name;
          };

          spec = {
            replicas = 1;

            selector.matchLabels = {
              "app.kubernetes.io/instance" = instance-name;
              "app.kubernetes.io/name" = name;
            };

            strategy.type = "Recreate";

            template = {
              metadata.labels = {
                "app.kubernetes.io/instance" = instance-name;
                "app.kubernetes.io/name" = name;
              };

              spec = {
                containers = [{
                  args = [ "--host=0.0.0.0" ];
                  image = "lncm/specter-desktop:${cfg.imageVersion}";
                  imagePullPolicy = "IfNotPresent";
                  livenessProbe = {
                    httpGet = {
                      path = "/";
                      port = "http";
                    };
                  };

                  name = "specter-desktop";

                  ports = [{
                    containerPort = 25441;
                    name = "http";
                    protocol = "TCP";
                  }];

                  readinessProbe = {
                    httpGet = {
                      path = "/";
                      port = "http";
                    };
                  };

                  securityContext.runAsUser = 1000;

                  volumeMounts = [{
                    mountPath = "/data";
                    name = "specter-data";
                  }];
                }];

                securityContext.fsGroup = 1000;

                serviceAccountName = "specter";

                volumes = [{
                  name = "specter-data";
                  persistentVolumeClaim.claimName = "specter-data";
                }];
              };
            };
          };
        };
      };

      ingresses = with cfg.ingress; {
        specter = {
          metadata.labels = {
            "app.kubernetes.io/instance" = instance-name;
            "app.kubernetes.io/name" = name;
          };

          spec = {
            inherit ingressClassName;

            rules = [{
              host = domain;
              http.paths = [{
                backend.service = {
                  name = "specter";
                  port.name = "http";
                };
                path = "/";
                pathType = "ImplementationSpecific";
              }];
            }];
            tls = [{
              hosts = [ domain ];
              secretName = "${name}-tls";
            }];
          };
        };
      };

      persistentVolumeClaims = {
        specter-data = {
          metadata.labels = {
            "app.kubernetes.io/instance" = instance-name;
            "app.kubernetes.io/name" = name;
          };

          spec = {
            accessModes = [ "ReadWriteOnce" ];
            resources.requests.storage = "1Gi";
            storageClassName = "longhorn";
          };
        };
      };

      serviceAccounts = {
        specter = {
          metadata.labels = {
            "app.kubernetes.io/instance" = instance-name;
            "app.kubernetes.io/name" = name;
          };
        };
      };

      services = {
        specter = {
          metadata.labels = {
            "app.kubernetes.io/instance" = instance-name;
            "app.kubernetes.io/name" = name;
          };

          spec = {
            ports = [{
              name = "http";
              port = 25441;
              protocol = "TCP";
              targetPort = "http";
            }];

            selector = {
              "app.kubernetes.io/instance" = instance-name;
              "app.kubernetes.io/name" = name;
            };

            type = "ClusterIP";
          };
        };
      };
    };
}
