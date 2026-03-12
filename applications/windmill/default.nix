{
  config,
  lib,
  pkgs,
  self,
  ...
}:
with lib;
let
  database-url-secret = "windmill-database-url";
  # Minimal URL-encode for postgresql:// URL: only chars that break parsing.
  # : separates user from password, @ separates password from host. % starts escape sequences.
  # Space and + can be misinterpreted; encode them. Avoid over-encoding.
  urlEncPassword = s:
    builtins.replaceStrings
      [ "%" "@" ":" " " "+" ]
      [ "%25" "%40" "%3A" "%20" "%2B" ]
      s;
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

    # Create DATABASE_URL as a SOPS secret, built from the configured Postgres connection.
    sopsSecrets =
      cfg:
      lib.optionalAttrs (cfg.database.password != "") {
        ${database-url-secret} = {
          DATABASE_URL =
            "postgresql://${cfg.database.username}:${urlEncPassword cfg.database.password}@${cfg.database.host}:${toString cfg.database.port}/${cfg.database.name}?sslmode=disable";
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

                containers = [
                  {
                    inherit name;
                    image = cfg.image;
                    imagePullPolicy = "IfNotPresent";
                    env =
                      [
                        {
                          name = "TZ";
                          value = cfg.tz;
                        }
                        # Windmill defaults MODE to standalone, but we set it explicitly.
                        {
                          name = "MODE";
                          value = "standalone";
                        }
                        # BASE_URL should be the external URL users hit (via ingress).
                        {
                          name = "BASE_URL";
                          value = "https://${cfg.ingress.domain}";
                        }
                      ]
                      ++ (
                        if cfg.database.password != "" then
                          [
                            {
                              name = "DATABASE_URL";
                              valueFrom = {
                                secretKeyRef = {
                                  name = database-url-secret;
                                  key = "DATABASE_URL";
                                };
                              };
                            }
                          ]
                        else
                          [ ]
                      );
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

