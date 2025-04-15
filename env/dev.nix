{ nixidy, lib, secrets, ... }:
let base-domain = "dev.kronkltd.net";
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
      domain = "cloudbeaver.${base-domain}";
      enable = false;
    };

    jupyterhub = {
      enable = true;
      domain = "jupyterhub.${base-domain}";
      ssl = true;
      inherit (secrets.jupyterhub)
        cookieSecret cryptkeeperKeys password proxyToken;
    };

    longhorn = {
      domain = "longhorn.${base-domain}";
      enable = true;
    };

    minio = {
      api-domain = "api.minio.${base-domain}";
      domain = "minio.${base-domain}";
      enable = true;
      tls.enable = true;
    };

    pihole.enable = false;
    postgresql.enable = true;
    satisfactory.enable = false;
    sealed-secrets.enable = true;
    sops.enable = true;
    spark.enable = false;

    tailscale = {
      enable = false;
      oauth = { inherit (secrets.tailscale) authKey clientId clientSecret; };
    };

    traefik.enable = true;
  };
}
