{ secrets, ... }:
let
  base-domain = "dev.kronkltd.net";
  tail-domain = "bearded-snake.ts.net";
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
    argocd.enable = true;
    cert-manager.enable = true;

    cloudbeaver = {
      domain = "cloudbeaver.${tail-domain}";
      enable = true;
    };

    harbor-nix = {
      domain = "harbor.${base-domain}";
      enable = true;
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
      domain = "longhorn.${tail-domain}";
      enable = true;
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
    satisfactory.enable = false;
    sealed-secrets.enable = true;

    # ../modules/sops/default.nix
    sops.enable = true;

    spark.enable = false;

    tailscale = {
      enable = true;
      oauth = { inherit (secrets.tailscale) authKey clientId clientSecret; };
    };

    traefik.enable = true;
  };
}
