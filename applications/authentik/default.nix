{
  ageRecipients,
  charts,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  postgresql-secret = "authentik-postgres-auth";
  secret-secret = "authentik-secret-key";
in
mkArgoApp { inherit config lib; } {
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

  defaultValues =
    cfg: with cfg; {
      authentik = {
        error_reporting.enabled = true;
        postgresql = {
          inherit (cfg.postgresql)
            host
            name
            password
            user
            ;
        };
        secret_key = "this is a secret";
      };

      global.env = [
        {
          name = "AUTHENTIK_SECRET_KEY";
          valueFrom.secretKeyRef = {
            name = secret-secret;
            key = "authentik-secret-key";
          };
        }
        # {
        #   name = "AUTHENTIK_POSTGRESQL__PASSWORD";
        #   valueFrom.secretKeyRef = {
        #     name = postgresql-secret;
        #     key = "password";
        #   };
        # }
      ];

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
        tls = [
          {
            secretName = "authentik-tls";
            hosts = [ domain ];
          }
        ];
        https = false;
      };
    };

  extraResources = cfg: {
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
      # authentik = lib.createSecret {
      #   inherit ageRecipients lib pkgs;
      #   inherit (cfg) namespace;
      #   secretName = "authentik";
      #   values = {
      #     AUTHENTIK_EMAIL_PORT = "587";
      #     AUTHENTIK_EMAIL_TIMEOUT = "30";
      #     AUTHENTIK_EMAIL_USE_SSL = "false";
      #     AUTHENTIK_EMAIL_USE_TLS = "false";
      #     AUTHENTIK_ENABLED = "true";
      #     AUTHENTIK_ERROR_REPORTING_ENABLED = "true";
      #     AUTHENTIK_ERROR_REPORTING_ENVIRONMENT = "k8s";
      #     AUTHENTIK_ERROR_REPORTING_SEND_PII = "false";
      #     AUTHENTIK_EVENTS__CONTEXT_PROCESSORS__ASN =
      #       "/geoip/GeoLite2-ASN.mmdb";
      #     AUTHENTIK_EVENTS__CONTEXT_PROCESSORS__GEOIP =
      #       "/geoip/GeoLite2-City.mmdb";
      #     AUTHENTIK_LOG_LEVEL = "info";
      #     AUTHENTIK_OUTPOSTS__CONTAINER_IMAGE_BASE =
      #       "ghcr.io/goauthentik/%(type)s:%(version)s";
      #     AUTHENTIK_POSTGRESQL__HOST = "postgreql.postgreql";
      #     AUTHENTIK_POSTGRESQL__NAME = "authentik";
      #     AUTHENTIK_POSTGRESQL__PASSWORD = "hunter2";
      #     AUTHENTIK_POSTGRESQL__PORT = "5432";
      #     AUTHENTIK_POSTGRESQL__USER = "postgresql";
      #     AUTHENTIK_REDIS__HOST = "authentik-redis-master";
      #     AUTHENTIK_SECRET_KEY = "this is a secret";
      #     AUTHENTIK_WEB__PATH = "/";
      #   };
      # };

      ${postgresql-secret} = lib.createSecret {
        inherit ageRecipients lib pkgs;
        inherit (cfg) namespace;
        secretName = postgresql-secret;
        values = {
          inherit (cfg.postgresql)
            password
            postgres-password
            replicationPassword
            ;
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
