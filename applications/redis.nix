{ ... }:
{
  flake.nixidyApps.redis =
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
        name = "redis";

        sopsSecrets = cfg: {
          ${password-secret} = {
            password = cfg.password;
          };
        };

        extraOptions = {
          image = mkOption {
            description = mdDoc "The docker image";
            type = types.str;
            default = "redis:8-alpine";
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

          replicas = mkOption {
            description = mdDoc "Number of Redis replicas";
            type = types.int;
            default = 1;
          };

          repairAof = mkOption {
            description = mdDoc "Deploy a one-shot job that runs redis-check-aof --fix on all incremental AOF files";
            type = types.bool;
            default = false;
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
                replicas = cfg.replicas;
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
                          "redis-server --requirepass \"$REDIS_PASSWORD\" --appendonly yes --aof-load-corrupt-tail-max-size 1181"
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

          jobs = lib.optionalAttrs cfg.repairAof {
            "${name}-aof-repair" = {
              spec = {
                backoffLimit = 0;
                ttlSecondsAfterFinished = 300;
                template.spec = {
                  restartPolicy = "Never";
                  volumes = [
                    {
                      name = "data";
                      persistentVolumeClaim.claimName = "${name}-${name}-data";
                    }
                  ];
                  containers = [
                    {
                      name = "aof-repair";
                      image = cfg.image;
                      imagePullPolicy = "IfNotPresent";
                      command = [
                        "sh"
                        "-c"
                        "for f in /data/appendonlydir/*.incr.aof; do echo \"Fixing $f\"; yes | redis-check-aof --fix \"$f\"; done"
                      ];
                      volumeMounts = [
                        {
                          mountPath = "/data";
                          name = "data";
                        }
                      ];
                    }
                  ];
                };
              };
            };
          };

          persistentVolumeClaims = {
            "${name}-${name}-data".spec = {
              inherit (cfg) storageClassName;
              accessModes = [ "ReadWriteOnce" ];
              resources.requests.storage = "10Gi";
            };
          };
        };
      };
}
