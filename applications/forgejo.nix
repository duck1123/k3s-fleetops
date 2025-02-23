{ lib, ... }:
let domain = "git.dev.kronkltd.net";
in {
  applications.forgejo = {
    namespace = "forgejo";
    createNamespace = true;

    helm.releases.forgejo = {
      chart = lib.helm.downloadHelmChart {
        repo = "https://code.forgejo.org/forgejo-helm";
        chart = "forgejo";
        version = "10.0.1";
        chartHash = "sha256-tndmg6tUHYnyWbiWVvxSI9tNQwjYBzWwNa8OXRSxYAQ=";
      };

      values = {
        gitea = {
          additionalConfigFromEnvs = [{
            name = "FORGEJO__DATABASE__PASSWD";
            valuesFrom.secretKeyRef = {
              key = "adminPassword";
              name = "postgresql-password";
              namespace = "postgresql";
            };
          }];

          admin.existingSecret = "forgejo-admin-password";
          config.database = {
            DB_TYPE = "postgres";
            HOST = "postgresql.postgresql:5432";
            USER = "postgres";
            NAME = "gitea";
            SCHEMA = "public";
          };

          metrics.enabled = true;
        };

        ingress = {
          annotations = {
            "cert-manager.io/cluster-issuer" = "letsencrypt-prod";
            "ingress.kubernetes.io/force-ssl-redirect" = "true";
          };
          enabled = true;
          className = "traefik";
          hosts = [{
            host = domain;
            paths = [{
              path = "/";
              pathType = "ImplementationSpecific";
            }];
          }];
          tls = [{
            secretName = "forgejo-tls";
            hosts = [ domain ];
          }];
        };

        postgresql.enabled = false;
        postgresql-ha.enabled = false;
        redis.enabled = false;
        redis-cluster.enabled = false;
      };
    };
  };
}
