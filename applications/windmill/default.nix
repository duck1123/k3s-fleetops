{
  config,
  lib,
  pkgs,
  self,
  ...
}:
with lib;
let
  db-password-secret = "windmill-database-password";
  shared-work-volume = "windmill-db-url-work";
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
    name = "windmill";
    uses-ingress = true;

    # Store only the raw password; init container builds DATABASE_URL at runtime with proper URL encoding.
    sopsSecrets =
      cfg:
      lib.optionalAttrs (cfg.database.password != "") {
        ${db-password-secret} = {
          password = cfg.database.password;
        };
      };

    extraOptions = {
      image = mkOption {
        description = mdDoc "The Windmill docker image";
        type = types.str;
        default = "ghcr.io/windmill-labs/windmill:latest";
      };

      service.port = mkOption {
        description = mdDoc "The service port";
        type = types.int;
        default = 8000;
      };

      storageClassName = mkOption {
        description = mdDoc "Storage class for optional local data (currently not used)";
        type = types.str;
        default = "longhorn";
      };

      database = {
        host = mkOption {
          description = mdDoc "PostgreSQL host (use your existing Postgres service)";
          type = types.str;
          default = "postgresql.postgresql";
        };

        port = mkOption {
          description = mdDoc "PostgreSQL port";
          type = types.int;
          default = 5432;
        };

        name = mkOption {
          description = mdDoc "PostgreSQL database name for Windmill";
          type = types.str;
          default = "windmill";
        };

        username = mkOption {
          description = mdDoc "PostgreSQL username for Windmill";
          type = types.str;
          default = "windmill";
        };

        password = mkOption {
          description = mdDoc "PostgreSQL password for Windmill (from your secrets)";
          type = types.str;
          default = "";
        };
      };

      tz = mkOption {
        description = mdDoc "Timezone";
        type = types.str;
        default = "Etc/UTC";
      };

      replicas = mkOption {
        description = mdDoc "Number of Windmill replicas";
        type = types.int;
        default = 1;
      };
    };

    extraResources = cfg: {
      deployments = {
        ${name} = {
          metadata.labels = {
            "app.kubernetes.io/instance" = name;
            "app.kubernetes.io/name" = name;
            "app.kubernetes.io/version" = "latest";
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

                # Build DATABASE_URL at runtime with proper URL encoding (handles special chars in password).
                initContainers = lib.optionals (cfg.database.password != "") [
                  {
                    name = "build-database-url";
                    image = "python:3-alpine";
                    imagePullPolicy = "IfNotPresent";
                    command = [
                      "python3"
                      "-c"
                      ''
                        import urllib.parse
                        import os
                        user = os.environ["PGUSER"]
                        password = os.environ["PGPASSWORD"]
                        host = os.environ["PGHOST"]
                        port = os.environ["PGPORT"]
                        db = os.environ["PGDATABASE"]
                        enc = urllib.parse.quote(password, safe="")
                        url = f"postgresql://{user}:{enc}@{host}:{port}/{db}?sslmode=disable"
                        with open("/work/database_url", "w") as f:
                            f.write(url)
                      ''
                    ];
                    env = [
                      {
                        name = "PGUSER";
                        value = cfg.database.username;
                      }
                      {
                        name = "PGHOST";
                        value = cfg.database.host;
                      }
                      {
                        name = "PGPORT";
                        value = toString cfg.database.port;
                      }
                      {
                        name = "PGDATABASE";
                        value = cfg.database.name;
                      }
                      {
                        name = "PGPASSWORD";
                        valueFrom.secretKeyRef = {
                          name = db-password-secret;
                          key = "password";
                        };
                      }
                    ];
                    volumeMounts = [
                      {
                        mountPath = "/work";
                        name = shared-work-volume;
                      }
                    ];
                  }
                ];

                containers = [
                  (
                    {
                      inherit name;
                      image = cfg.image;
                      imagePullPolicy = "IfNotPresent";
                      env = [
                        {
                          name = "TZ";
                          value = cfg.tz;
                        }
                        {
                          name = "MODE";
                          value = "standalone";
                        }
                        {
                          name = "BASE_URL";
                          value = "https://${cfg.ingress.domain}";
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
                        httpGet = {
                          path = "/healthz";
                          port = cfg.service.port;
                        };
                        initialDelaySeconds = 20;
                        periodSeconds = 10;
                        timeoutSeconds = 5;
                        successThreshold = 1;
                        failureThreshold = 5;
                      };
                      livenessProbe = {
                        httpGet = {
                          path = "/healthz";
                          port = cfg.service.port;
                        };
                        initialDelaySeconds = 40;
                        periodSeconds = 30;
                        timeoutSeconds = 5;
                        successThreshold = 1;
                        failureThreshold = 5;
                      };
                    }
                    // lib.optionalAttrs (cfg.database.password != "") {
                      command = [
                        "/bin/sh"
                        "-c"
                        "export DATABASE_URL=$(cat /work/database_url) && exec windmill standalone"
                      ];
                      volumeMounts = [
                        {
                          mountPath = "/work";
                          name = shared-work-volume;
                        }
                      ];
                    }
                  )
                ];

                volumes = lib.optionals (cfg.database.password != "") [
                  {
                    name = shared-work-volume;
                    emptyDir = { };
                  }
                ];
              };
            };
          };
        };
      };

      ingresses.${name}.spec = with cfg.ingress; {
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
  }
