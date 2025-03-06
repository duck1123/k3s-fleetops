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
      enabled = true;
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
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.forgejo = { inherit chart values; };

      resources.sealedSecrets = {
        forgejo-admin-password.spec = {
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

        postgresql-password.spec = {
          encryptedData = {
            adminPassword =
              "AgBG7ZXfctZb8wMB5TW9kCh0ZZpg8oSisL8tvx60iaDEP2g0Vxn24XxIn5EYa76q7qutUat8yJqIG4BZprkMHCGRAg/WKWIb8xSf8XEfBps1aouuBZZSKfp1E39jtlszV8VB6S9MwPm6NIksHDH8g+dLZ2xjnflRb5TMKAbDqLejgBBPRO+HoXllUy9Wa/iAoolTg3DLZioLk2SMlWC9Ataj+Axd4JaEyK+DOLWH/pDlyZi1RJXfJerX30foiCAlwhEHA93dOIZazjjYRRC0VekOTNS5FHL9NxwOpjdhWVZcggQE6DpC1gr6geK+xVt7yK8YLSAQ4A3V9UWgnSekgaQP2R2/VEywhOMUXKaNP0Vyd/2u8HemkwXjVNsHNV6/fMaT+xvUVUy3Qc2DibX6pwsPwdyGYXYZs87/Q9mwNzNWdB8wAVD7+FUofrqyk0Q2/Lw0spcdtTnfw9wtRWf84RfnIWX6FM4rvjthvzpYdck7P6at/d0+zfJsJS3A+uTTUEWgZMzVxai0sSCAQwjWTGXM6FBlLirnsHsdXOyn1faXfE83PmNM3aB9ig+uNlgUtts8MEZO7PpzS9f3ylwKJ0G/qQJNz46Jw3CCZGBR2J9TRaIrK9kNGsgfO8AdtowCefU/dqnU8kkeuyW3LtzWhDokWwJ5zobMZpobwjztPTsdVQAPUEENXDV0EG5nmbw3HY80G+Oqm0mfnNB3QR3h2AjsEPXrIg==";
            adminUsername =
              "AgAKFwqVge7uia0rb+rEp19V2MZLV7H86CCEpNwE0ZEdkzDrVM78SZGdmuq5axIru9VV5jzLhemhah0RQh6t6PDk0W8daAZhCs9KjH+yZOBJ7EzYspM0IMw2KpFjbHMKif7tZ/1qOYeMJgWxwXvIoMvx7aFNuQPy3sEvxtP5T+SpYwuw2/93JUOxIbNIT3yiQJN74douE6TWG49XOJDfqgWsfa0dqM4pBUQt1py91P3Ra7qv8r/Yeo9zrVKDZ0pH7AihoyMCb2ooR7l8Z5tU4ostPf8bNDDEo7NGZNmHr0i9XxbbjlrWzhkoR6jSFGOzcKDFbAgVIu4Ht9u11+sLNDQYRDvy+CeIzmRzXMKLjQeUIOhdHN5WIjx00AOZatLa+2RU5A3UsPTLXawfu8ncjItY6l7y/FdzTiReTBK8XFS2cUCViHVSNQ//aKRtGOpgRcN2WVOy3HZESWPkWCfBTrLRnlt0yL3rSa/2UH9dnBqQ4iTWtOjslgGpsz11rFIqsHzw5om/uj2emBKmaQeXxJIC/XdEMavyNriPYJHCJe1YwE5WsF9xIfdIy3l+3rzHWmkva1pFs4HiWBRJCMY6EcmgEJyvLCVvZnfb1UmEm4VVWQ6pMyx2jPiOdJa0Yu7oABt/Gj7jbM1DKVR6WH4VNCuyRj9+3ZJWzuqDJXfTBaMnjplzAJOLSMiWcGsnv7Tx5GOROcwCZer8yA==";
            replicationPassword =
              "AgCEgIXIaJ+wOpCONYV4Nnf4UhQs3fuXH+4KM6OqWvtBsec10XQwKae1nwNfQUGwIqfJyseVpA4u9QW1yqNOKgbh4R95niE1OTmtLrNxBc+5LZdN0qE/o+2jrHQ00rgcUu56UO/RN54Ip9jQx1dE4Yx8cc7xGniJqn3t+Du7TsHkfTXjYeg9tuY/Kc/myawF6KQxCq90AMNcDc2zuErPqTdgzborgxRVCnZ7OzdRKdy3qgZaTj0aoJGcIDv2vjfEE33QV6QMPEZyO2pMEG2eZux94vf/SQcFLq3OZJEEBDGH/IOwlPKd2WjjPnHzZB15kIotRRtszDEGS12sZXQRq9Pq7Bw5A5aKOnTzvqU9iPNR1vkzr1rWdgSt8Ot5nJ9QJvU8e25/J919/ArwL+ADbmSJC6QCeVTcAw8+r4P/uF0ewfhIKZgT5ctNVhqruTfBrPeoVHNRUN3iAfyGa97jEsV9Jeml3e9Y7ltYR8+4N9mzk7KtgP8qn0SWAumiFekHFNe9jjLT+FZAl8XYkA7FwsZ5v2E/AaP7zUINFeT1f+whAU3WYHxqzffnKNtkizA+xECqy2EJTr0TqXema8T2P3aGi6a1KNo1gPmzIHa2J8hh227n8xZUrrdDZMGvaHzreO5ees2aF/fg/bCQj9KlydqhXoYQvUGRy/WtY/vKp89Tl7hjAuYGxLgos/GUVAB7cm8yRgWB4AB8gE7SkVN43VMEhaoj1w==";
            userPassword =
              "AgAqqPac+7CzoHBXu2khGSTQPqR66GR3wjU+L0Q7ftvY6l7k/jpzcPx4C8H2aUVGjS5sk/u/lqrB7mJdsa+u1Uud2TEwS9+JFPHHeYJwoShqZEd/SnAnTgWb+RLzJiypJ1NVzcSbkNipCOMxox3aXY3i6WHgy/fAGiYdjZcvY24neWWAa21notCU/lYTlatPt3EJWMeE20RUAB4wNQqjua7d3vshBglZ+K6HkLccc79/5uqnVP7DiI0DDOWt8s5m6U8KmptWuY82GydIR4oygAMI16KZP4s8ic0qrynmvCzkesXjBEr4h80ZQtCBYbAkyk26XOXTXXXZkrcZSEalnEyb+lEfvWN+UFTTMfQVXySZ4QNRXMF0XqPD13/i+zUFGc0/GHjQ02Wm9B7WL2eET+qFCkqxvXWeOxqnISfaepT0GuTQWWnx15kxYHR7Kn1r2VOeobSRzA/W0CwpKU6tfXTHjYTpAl98KrAOB+AQKZf1t32pBYcg9fL8mS8KQgS0a4nvfxjuPD/iw5GOEkbkCQ48PFg27vcttmiBW9RHDuASqo1nnmDqqFK66PEtuSbAqxj2Xc6CHwB1/+PLkuhpdmdwCpQKK5410AK5YsxAysRyKHecsTTP03ryUicJtIiz0k1fhWNofmGJOs5KGtOUcM/qfOVJhOLeT5u6D0KHdpzRJ3MXOUbVSe6IRrkmks25T3K49TxAtn8O/0QF2fcHdQh/KhOf+g==";
          };

          template.metadata = {
            creationTimestamp = null;
            name = "postgresql-password";
            namespace = cfg.namespace;
          };
        };
      };
    };
  };
}
