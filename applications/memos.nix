{ ... }:
{
  flake.nixidyApps.memos =
    {
      config,
      lib,
      pkgs,
      self,
      ...
    }:
    with lib;
    let
      db-secret = "memos-database";
      # Memos parses MEMOS_DSN with net/url; userinfo must be percent-encoded (passwords with : ) @ ; etc.).
      enc = pkgs.lib.escapeURL;
      postgresDsn =
        cfg:
        "postgresql://${enc cfg.database.username}:${enc cfg.database.password}@${cfg.database.host}:${toString cfg.database.port}/${cfg.database.name}?sslmode=disable";
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
        name = "memos";

        # https://artifacthub.io/packages/helm/gabe565/memos
        chart = lib.helm.downloadHelmChart {
          repo = "https://charts.gabe565.com";
          chart = "memos";
          version = "0.15.1";
          chartHash = "sha256-k9UU0fLgFgn/aogTD+PMxcQOnZ9g47vFXeyhnf2hqbQ=";
        };

        uses-ingress = true;

        extraOptions = {
          database = {
            host = mkOption {
              description = mdDoc "PostgreSQL service host (cluster DNS)";
              type = types.str;
              default = "postgresql.postgresql";
            };
            port = mkOption {
              description = mdDoc "PostgreSQL port";
              type = types.int;
              default = 5432;
            };
            name = mkOption {
              description = mdDoc "Database name";
              type = types.str;
              default = "memos";
            };
            username = mkOption {
              description = mdDoc "Database user";
              type = types.str;
              default = "postgres";
            };
            password = mkOption {
              description = mdDoc "Database password (embedded in DSN with URL-encoding for special characters)";
              type = types.str;
              default = "";
            };
          };
        };

        sopsSecrets =
          cfg:
          optionalAttrs (cfg.database.password != "") {
            ${db-secret}.memos-dsn = postgresDsn cfg;
          };

        defaultValues =
          cfg:
          {
            ingress.main = with cfg.ingress; {
              enabled = false;
              hosts = [
                {
                  host = domain;
                  paths = [ { path = "/"; } ];
                }
              ];
              tls = [
                {
                  secretName = "memo-tls";
                  hosts = [ domain ];
                }
              ];
            };
            persistence.data.enabled = false;
            postgresql.enabled = false;
          }
          // optionalAttrs (cfg.database.password != "") {
            env = {
              MEMOS_DRIVER = "postgres";
              MEMOS_DSN = {
                valueFrom.secretKeyRef = {
                  name = db-secret;
                  key = "memos-dsn";
                };
              };
            };
          };

        extraResources =
          cfg: with cfg; {
            ingresses = with cfg.ingress; {
              memos.spec = {
                inherit (cfg.ingress) ingressClassName;
                rules = [
                  {
                    host = domain;
                    http = {
                      paths = [
                        {
                          path = "/";
                          pathType = "ImplementationSpecific";
                          backend.service = {
                            inherit name;
                            port.name = "http";
                          };
                        }
                      ];
                    };
                  }
                ];
                tls = [
                  {
                    hosts = [ domain ];
                    secretName = tls.secretName;
                  }
                ];
              };
            };
          };
      };
}
