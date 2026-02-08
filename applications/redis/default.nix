{
  config,
  lib,
  pkgs,
  self,
  ...
}:
with lib;
let
  password-secret = "redis-password";
in
mkArgoApp { inherit config lib; } rec {
  name = "redis";

  extraOptions = {
    image = mkOption {
      description = mdDoc "The docker image";
      type = types.str;
      default = "redis:7-alpine";
    };

    storageClassName = mkOption {
      description = mdDoc "The storage class";
      type = types.str;
      default = "longhorn";
    };

    password = mkOption {
      description = mdDoc "The password";
      type = types.str;
      default = "CHANGEME";
    };

    port = mkOption {
      description = mdDoc "The Redis port";
      type = types.int;
      default = 6379;
    };
  };

  extraResources = cfg: {
    deployments = {
      redis = {
        metadata.labels = {
          "app.kubernetes.io/instance" = name;
          "app.kubernetes.io/name" = name;
        };

        spec = {
          replicas = 1;
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
                  name = "redis";
                  image = cfg.image;
                  imagePullPolicy = "IfNotPresent";
                  command = [
                    "sh"
                    "-c"
                    "redis-server --requirepass \"$REDIS_PASSWORD\" --appendonly yes"
                  ];
                  env = [
                    {
                      name = "REDIS_PASSWORD";
                      valueFrom.secretKeyRef = {
                        name = password-secret;
                        key = "password";
                      };
                    }
                  ];
                  ports = [
                    {
                      containerPort = cfg.port;
                      name = "redis";
                      protocol = "TCP";
                    }
                  ];

                  livenessProbe = {
                    exec = {
                      command = [
                        "sh"
                        "-c"
                        "redis-cli --no-auth-warning -a \"$REDIS_PASSWORD\" ping"
                      ];
                    };
                    initialDelaySeconds = 30;
                    periodSeconds = 10;
                    timeoutSeconds = 5;
                  };

                  readinessProbe = {
                    exec = {
                      command = [
                        "sh"
                        "-c"
                        "redis-cli --no-auth-warning -a \"$REDIS_PASSWORD\" ping"
                      ];
                    };
                    initialDelaySeconds = 5;
                    periodSeconds = 5;
                    timeoutSeconds = 3;
                  };

                  volumeMounts = [
                    {
                      mountPath = "/data";
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
    };

    services = {
      redis.spec = {
        ports = [
          {
            name = "redis";
            port = cfg.port;
            protocol = "TCP";
            targetPort = "redis";
          }
        ];

        selector = {
          "app.kubernetes.io/instance" = name;
          "app.kubernetes.io/name" = name;
        };

        type = "ClusterIP";
      };
    };

    persistentVolumeClaims = {
      "${name}-${name}-data".spec = {
        inherit (cfg) storageClassName;
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "10Gi";
      };
    };

    sopsSecrets.${password-secret} = lib.createSecret {
      inherit lib pkgs;
      inherit (config) ageRecipients;
      inherit (cfg) namespace;
      inherit (self.lib) encryptString toYAML;
      secretName = password-secret;
      values = with cfg; {
        inherit password;
      };
    };
  };
}
