{ charts, config, lib, pkgs, ... }:
let
  cfg = config.services.forgejo;

  chart = lib.helmChart {
    inherit pkgs;
    chartTgz = ../../charts/forgejo-11.0.3.tgz;
    chartName = "forgejo";
  };

  defaultNamespace = "forgejo";
  domain = "git.dev.kronkltd.net";

  # https://artifacthub.io/packages/helm/forgejo-helm/forgejo
  defaultValues = {
    gitea = {
      additionalConfigFromEnvs = [{
        name = "FORGEJO__DATABASE__PASSWD";
        valueFrom.secretKeyRef = {
          key = "adminPassword";
          name = "postgresql-password";
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
      className = "traefik";
      enabled = false;
      hosts = [{
        host = domain;
        paths = [{
          path = "/";
          pathType = "ImplementationSpecific";
        }];
      }];
      tls = [{
        hosts = [ domain ];
        secretName = "forgejo-tls";
      }];
    };

    postgresql.enabled = false;
    postgresql-ha.enabled = false;
    redis.enabled = false;
    redis-cluster.enabled = false;
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.forgejo = {
    enable = mkEnableOption "Enable application";
    namespace = mkOption {
      description = mdDoc "The namespace to install into";
      type = types.str;
      default = defaultNamespace;
    };

    values = mkOption {
      description = "All the values";
      type = types.attrsOf types.anything;
      default = { };
    };
  };

  config = mkIf cfg.enable {
    applications.forgejo = {
      inherit namespace;
      createNamespace = true;
      helm.releases.forgejo = { inherit chart values; };

      resources.sealedSecrets.forgejo-admin-password.spec = {
        encryptedData = {
          password =
            "AgCqZ0EmJmvJxXGlPV9l2EfOeYUgQKPnlgpB+YdfoburcujiPRDoAP/5DfTedtFXD1NlWaFpF66VSMFBJTF1QiJYKZm7lQgyv7SKWtQsZf/KPG5hLn9kCVlYlcQ2OLveW8++OWpuR83TJ+UYz2TtRaPJ4gejPZpnzFpXuaPQDtkcGLwaLsGAP0HjVNTP28oeZLFmnB634nreJA+wIbE4J6Br+X7abqJ9N1k8foNpryMdNA/mZ3ng5bumC8miAKmvF5III36dxMsrDls2gISq1NXTIB2bYxxj3ElIbg8rC42l105zyZEYZBPFN7bf7TRsppeTlpYwZWvuen1/xMqYqQnd1Ol5FbmdGpshAyfBiLNCIRf1uR5CdArkUvGgdAlaggwWR1VaZedNa6OfTKpM5coP+QM5NTWPg0cYHBqHoUEUNWy+X1z29n9vGXLpSMv+GKKe1ZvVAG+tlog0TbgywTOYSe38/wulOHVxqd2CYMU29a68ToTJnPVdzQ/wvSHS5VZ6tvWxBtSLSSCgWUy4+9gOGC+3yL05ewfIYfS3yeSBp2klOq0b4qXQ0FfMtNGwRfOnVQMFQMf+sGqfTO37Xzzmlfytyeh9/D2cto4pyiIfgnxRX32IpgNq0bLegG3mYc04D2LDbcmhfA2h8e4KibRW7DI0hSWxCiTa+QueFo9C65KjU7h4ins7uXFcQuY/hOR/AqYSX+oyM0tn1QZHZRntQbUgOw==";
          username =
            "AgA04L8YXDmFYE0yUXHDHjako8I/JZ+8a6mhexqbUv2SR6HbUQy1zenp8SEHfYnTXr/FZ7heNNIowKMbVozln0vEkdKqa4Kmr5HQCuD7spUwUymyfQtO0r0oXduNfdvdVPOvpGDM9IIq37ncWM/3UG9enMQSwljU+xvsuPKWHmHskYZ3FL5eybF2nhlZoOMS+a9zvasi310VzcMDceKnTZu3OdoxEWxThkbKHzV+BADJhdbMed9EOjs6NSIM68ZUqQiioPQOLiq1zNAYDp7gna0Bl8EjtjCZSoLv+7MIwcknDIwMJFHx9cZ9h2gEvQGV/1YugNc0y8IdpMnla4AFJVZcBpvq9Cevn+ZGU2z+wH5tylm1N2J7bxfPg+fWCY+aHo7EyXXF0RKfOd/Qr3uYINQiFpMS6WHS6J12CysaROEYVPIOSPjbhFlN0/94bx+J5gAkm9Dxwve44OwFtlLgKuy01PBsL/6nFwWpZaXNW9NVkSbgIVdCFkQB9C/P/D2SYu9Tuk9Cw5iYaVdyj5F0YJA2YKLeScBQ2649a3cwniaP7ca+8FEsN6RNMxNrtq06/jRe7ed2eJs2DXHh//nKg0eQThwu/j6oy/4d2HpAOQ77kkBCWDbJgooqrv6X9BhO8uc8KP+3rMqQ2Z4FkHh5e90Cb+ZuxxzfhAolH8HPoWb0tccADehWI80+feJGJr1x2RVWXcrk";
        };

        template.metadata = {
          creationTimestamp = null;
          name = "forgejo-admin-password";
          namespace = cfg.namespace;
        };
      };
    };
  };
}
