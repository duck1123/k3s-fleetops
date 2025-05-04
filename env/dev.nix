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

    argocd.enable = true;
    cert-manager.enable = true;

    cloudbeaver = {
      domain = "cloudbeaver.${tail-domain}";
      enable = false;
    };

    harbor-nix = {
      domain = "harbor.${base-domain}";
      enable = false;
    };

    jupyterhub = {
      enable = false;
      domain = "jupyterhub.${tail-domain}";
      ssl = true;
      inherit (secrets.jupyterhub)
        cookieSecret cryptkeeperKeys password proxyToken;
    };

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

    minio = {
      api-domain = "api.minio.${tail-domain}";
      domain = "minio.${tail-domain}";
      enable = false;
      tls.enable = true;
    };

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

    satisfactory.enable = false;
    sealed-secrets.enable = true;

    # ../modules/sops/default.nix
    sops.enable = true;

    spark.enable = false;

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
