{ secrets, ... }:
let
  base-domain = "dev.kronkltd.net";
  tail-domain = "bearded-snake.ts.net";
  clusterIssuer = "letsencrypt-prod";
in {
  nixidy = {
    defaults.syncPolicy.autoSync = {
      enabled = true;
      prune = true;
      selfHeal = true;
    };

    target = {
      branch = "master";
      repository = "https://github.com/duck1123/k3s-fleetops.git";
      rootPath = "./manifests/dev";
    };
  };

  services = {
    # ../modules/adventureworks/default.nix
    adventureworks.enable = false;

    # ../modules/airflow/default.nix
    airflow = {
      enable = false;

      ingress = {
        inherit clusterIssuer;
        domain = "airflow.${base-domain}";
      };
    };

    # ../modules/alice-bitcoin/default.nix
    alice-bitcoin.enable = false;

    # ../modules/alice-lnd/default.nix
    alice-lnd = let user-env = "alice";
    in {
      inherit user-env;
      enable = false;
      imageVersion = "v1.10.3";
      ingress.domain = "lnd-${user-env}.dinsro.com";
    };

    # ../modules/alice-specter/default.nix
    alice-specter = let user-env = "alice";
    in {
      inherit user-env;
      enable = false;
      imageVersion = "v1.10.3";
      ingress.domain = "specter-${user-env}.dinsro.com";
      namespace = "${user-env}-specter";
    };

    # ../modules/argocd/default.nix
    argocd.enable = true;

    # ../modules/argo-workflows/default.nix
    argo-workflows = {
      enable = false;

      ingress = {
        domain = "argo-workflows.${base-domain}";
        ingressClassName = "traefik";
      };
    };

    # ../modules/authentik/default.nix
    authentik = {
      enable = false;

      ingress = {
        inherit clusterIssuer;
        domain = "authentik.${base-domain}";
        ingressClassName = "traefik";
      };

      inherit (secrets.authentik) secret-key;
      postgresql = {
        inherit (secrets.authentik.postgresql) password postgres-password replicationPassword;
        host = "postgreql.postgreql";
      };
    };

    cert-manager.enable = true;

    # ../modules/cloudbeaver/default.nix
    cloudbeaver = {
      enable = false;

      ingress = {
        domain = "cloudbeaver.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };
    };

    # ../modules/crossplane/default.nix
    crossplane = {
      enable = true;
      providers.digital-ocean.enable = true;
    };

    # ../modules/dinsro/default.nix
    dinsro = {
      enable = false;

      ingress = {
        domain = "dinsro.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };
    };

    # ../modules/forgejo/default.nix
    forgejo = {
      enable = true;

      admin = { inherit (secrets.forgejo.admin) password username; };

      ingress = {
        domain = "forgejo.${tail-domain}";
        ingressClassName = "tailscale";
      };

      postgresql = {
        inherit (secrets.forgejo.postgresql) adminPassword adminUsername;
      };
    };

    harbor-nix = {
      domain = "harbor.${base-domain}";
      enable = false;
    };

    # ../modules/homer/default.nix
    homer = {
      codeserver.ingress.domain = "codeserver.${tail-domain}";
      enable = false;
      ingress = {
        domain = "homer.${tail-domain}";
        ingressClassName = "tailscale";
      };
    };

    # ../modules/jupyterhub/default.nix
    jupyterhub = {
      enable = false;
      inherit (secrets.jupyterhub)
        cookieSecret cryptkeeperKeys password proxyToken;

      ingress = {
        domain = "jupyterhub.${tail-domain}";
        clusterIssuer = "tailscale";
        ingressClassName = "tailscale";
        tls.enable = true;
      };

      postgresql = {
        inherit (secrets.jupyterhub.postgresql) adminPassword;
      };
    };

    keycloak = {
      enable = false;
      ingress = {
        domain = "keycloak.dev.kronkltd.net";
        adminDomain = "keycloak-admin.dev.kronkltd.net";
        clusterIssuer = "letsencrypt-prod";
      };
    };

    # ../modules/kyverno/default.nix
    kyverno.enable = false;

    # ../modules/lldap/default.nix
    lldap.enable = false;

    # ../modules/longhorn/default.nix
    longhorn = {
      enable = true;

      ingress = {
        domain = "longhorn.${tail-domain}";
        ingressClassName = "tailscale";
        tls.enable = true;
      };
    };

    marquez = {
      domain = "marquez.${base-domain}";
      enable = false;
    };

    # ../modules/memos/default.nix
    memos = {
      enable = false;

      ingress = {
        domain = "memos.${tail-domain}";
        ingressClassName = "tailscale";
      };
    };

    # ../modules/metabase/default.nix
    metabase = {
      enable = false;

      ingress = {
        domain = "metabase.${tail-domain}";
        ingressClassName = "tailscale";
      };
    };

    # ../modules/mindsdb/default.nix
    mindsdb = {
      enable = false;

      ingress = {
        domain = "mindsdb.${tail-domain}";
        ingressClassName = "tailscale";
      };
    };

    # ../modules/minio/default.nix
    minio = {
      enable = false;

      ingress = {
        api-domain = "api.minio.${tail-domain}";
        domain = "minio.${tail-domain}";
        clusterIssuer = "tailscale";
        ingressClassName = "tailscale";
        tls.enable = true;
      };

      values.defaultBuckets = "my-default-bucket";
    };

    # ../modules/mssql/default.nix
    mssql.enable = false;

    # ../modules/nocodb/default.nix
    nocodb = {
      enable = false;

      ingress = {
        domain = "nocodb.${tail-domain}";
        ingressClassName = "tailscale";
      };

      databases = {
        minio = {
          inherit (secrets.nocodb.minio)
            bucketName endpoint region rootPassword rootUser;
        };
        postgresql = {
          inherit (secrets.nocodb.postgresql)
            database password postgresPassword replicationPassword username;
        };
        redis = { inherit (secrets.nocodb.redis) password; };
      };
    };

    pihole.enable = false;
    postgresql.enable = true;

    # ../modules/redis/default.nix
    redis = {
      enable = true;
      password = secrets.redis.password;
    };

    # ../modules/satisfactory/default.nix
    satisfactory.enable = false;

    # ../modules/sealed-secrets/default.nix
    sealed-secrets.enable = true;

    # ../modules/sops/default.nix
    sops.enable = true;

    # ../modules/spark/default.nix
    spark = {
      enable = false;

      ingress = {
        domain = "spark.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };
    };

    tailscale = {
      enable = true;
      oauth = { inherit (secrets.tailscale) authKey clientId clientSecret; };
    };

    tempo = {
      enable = false;
      ingress = {
        inherit clusterIssuer;
        domain = "tempo.${base-domain}";
        ingressClassName = "traefik";
      };
    };

    traefik.enable = true;
  };
}
