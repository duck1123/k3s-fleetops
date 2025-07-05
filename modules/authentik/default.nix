{ ageRecipients, charts, config, lib, pkgs, ... }:
with lib;
let
  postgresql-secret = "authentik-postgres-auth";
  secret-secret = "authentik-secret-key";
in mkArgoApp { inherit config lib; } {
  name = "authentik";

  # https://artifacthub.io/packages/helm/goauthentik/authentik
  chart = lib.helm.downloadHelmChart {
    repo = "https://charts.goauthentik.io/";
    chart = "authentik";
    version = "2025.6.3";
    chartHash = "sha256-KDAuA7Wmn1Q+OOUyZh2uD1FwTFlWOm5yOkKQDbZFKUg=";
  };

  uses-ingress = true;

  extraOptions = {
    postgresql = {
      host = mkOption {
        description = mdDoc "The postgreql host";
        type = types.str;
        default = "authentik-postgresql";
      };

      name = mkOption {
        description = mdDoc "The postgreql database name";
        type = types.str;
        default = "authentik";
      };

      password = mkOption {
        description = mdDoc "The admin password";
        type = types.str;
        default = "CHANGEME";
      };

      postgres-password = mkOption {
        description = mdDoc "The user password";
        type = types.str;
        default = "CHANGEME";
      };

      replicationPassword = mkOption {
        description = mdDoc "The replication password";
        type = types.str;
        default = "CHANGEME";
      };

      user = mkOption {
        description = mdDoc "The database user";
        type = types.str;
        default = "postgresql";
      };
    };

    secret-key = mkOption {
      description = mdDoc "The secret key";
      type = types.str;
      default = "CHANGEME";
    };
  };

  defaultValues = cfg:
    with cfg; {
      authentik = {
        error_reporting.enabled = true;
        postgresql = { inherit (cfg.postgresql) host name password user; };
      };

      # global.env = [
      #   {
      #     name = "AUTHENTIK_SECRET_KEY";
      #     valueFrom.secretKeyRef = {
      #       name = secret-secret;
      #       key = "authentik-secret-key";
      #     };
      #   }
      #   {
      #     name = "AUTHENTIK_POSTGRESQL__PASSWORD";
      #     valueFrom.secretKeyRef = {
      #       name = postgresql-secret;
      #       key = "password";
      #     };
      #   }
      # ];

      postgresql = with cfg.postgresql; {
        inherit host;
        auth.existingSecret = postgresql-secret;
        enabled = false;
      };

      redis.enabled = true;

      server.ingress = with ingress; {
        enabled = true;
        inherit ingressClassName;
        annotations = {
          "cert-manager.io/cluster-issuer" = clusterIssuer;
          "ingress.kubernetes.io/force-ssl-redirect" = "true";
          "ingress.kubernetes.io/proxy-body-size" = "0";
          "ingress.kubernetes.io/ssl-redirect" = "true";
        };
        hosts = [ domain ];
        tls = [{
          secretName = "authentik-tls";
          hosts = [ domain ];
        }];
        https = false;
      };
    };

  extraResources = cfg:
    with cfg; {
      middlewares.middlewares-authentik.spec.forwardAuth = {
        address = "http://authentik-server/outpost.goauthentik.io/auth/traefik";
        trustForwardHeader = true;
        authResponseHeaders = [
          "X-authentik-username"
          "X-authentik-groups"
          "X-authentik-email"
          "X-authentik-name"
          "X-authentik-uid"
          "X-authentik-jwt"
          "X-authentik-meta-jwks"
          "X-authentik-meta-outpost"
          "X-authentik-meta-provider"
          "X-authentik-meta-app"
          "X-authentik-meta-version"
        ];
      };

      sopsSecrets = {
        ${postgresql-secret} = lib.createSecret {
          inherit ageRecipients lib pkgs;
          inherit (cfg) namespace;
          secretName = postgresql-secret;
          values = {
            inherit (cfg.postgresql)
              password postgres-password replicationPassword;
          };
        };
        ${secret-secret} = lib.createSecret {
          inherit ageRecipients lib pkgs;
          inherit (cfg) namespace;
          secretName = secret-secret;
          values.authentik-secret-key = cfg.secret-key;
        };
      };
    };
}
