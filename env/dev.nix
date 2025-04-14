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
    cloudbeaver.enable = false;

    jupyterhub = {
      enable = false;
      domain = "jupyterhub.${base-domain}";
      ssl = true;
      inherit (secrets.jupyterhub)
        cookieSecret cryptkeeperKeys password proxyToken;
    };

    longhorn.enable = true;

    minio = {
      api-domain = "minio-api.${base-domain}";
      domain = "minio.${base-domain}";
      enable = false;
      tls.enable = true;
    };

    pihole.enable = false;
    postgresql.enable = false;
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
