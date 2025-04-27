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
    # ../modules/airflow/default.nix
    airflow = {
      enable = false;

      ingress = {
        domain = "airflow.${base-domain}";
        clusterIssuer = "letsencrypt-prod";
      };
    };

    argocd.enable = true;
    cert-manager.enable = true;

    # ../modules/cloudbeaver/default.nix
    cloudbeaver = {
      enable = true;

      ingress = {
        domain = "cloudbeaver.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };
    };

    harbor-nix = {
      domain = "harbor.${base-domain}";
      enable = true;
    };

    # ../modules/homer/default.nix
    homer = {
      codeserver.ingress.domain = "codeserver.${tail-domain}";
      enable = false;
      ingress.domain = "homer.${tail-domain}";
    };

    # ../modules/jupyterhub/default.nix
    jupyterhub = {
      enable = true;

      inherit (secrets.jupyterhub)
        cookieSecret cryptkeeperKeys password proxyToken;

      ingress = {
        domain = "jupyterhub.${tail-domain}";
        clusterIssuer = "tailscale";
        ingressClassName = "tailscale";
        tls.enable = true;
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

    # ../modules/longhorn/default.nix
    longhorn = {
      enable = true;

      ingress = {
        domain = "longhorn.${tail-domain}";
      };
    };

    marquez = {
      enable = false;

      ingress = {
        domain = "marquez.${base-domain}";
      };
    };

    # ../modules/minio/default.nix
    minio = {
      enable = true;

      ingress = {
        api-domain = "api.minio.${tail-domain}";
        domain = "minio.${tail-domain}";
        clusterIssuer = "tailscale";
        ingressClassName = "tailscale";
        tls.enable = true;
      };
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

    # ../modules/tailscale/default.nix
    tailscale = {
      enable = true;
      oauth = { inherit (secrets.tailscale) authKey clientId clientSecret; };
    };

    traefik.enable = true;
  };
}
