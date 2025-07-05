{ ageRecipients, charts, config, lib, pkgs, ... }:
with lib;
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

    };

    secret-key = mkOption {
      description = mdDoc "The secret key";
      type = types.str;
      default = "CHANGEME";
    };
  };

  defaultValues = cfg: with cfg; {
    authentik.error_reporting.enabled = true;
    global.env = [
      {
        name = "AUTHENTIK_SECRET_KEY";
        valueFrom.secretKeyRef = {
          name = "authentik-secret-key";
          key = "authentik-secret-key";
        };
      }
      {
        name = "AUTHENTIK_POSTGRESQL__PASSWORD";
        valueFrom.secretKeyRef = {
          name = "authentik-postgres-auth";
          key = "password";
        };
      }
    ];
    postgresql = {
      enabled = true;
      auth.existingSecret = "authentik-postgres-auth";
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

  extraResources = cfg: with cfg; {
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
      authentik-postgres-auth = lib.createSecret {
        inherit ageRecipients lib pkgs;
        inherit (cfg) namespace;
        secretName = "authentik-postgres-auth";
        values = { inherit (cfg.postgresql) password postgres-password replicationPassword; };
      };
      authentik-secret-key = lib.createSecret {
        inherit ageRecipients lib pkgs;
        inherit (cfg) namespace;
        secretName = "authentik-secret-key";
        values = { authentik-secret-key = cfg.secret-key; };
      };
    };
  };
}
