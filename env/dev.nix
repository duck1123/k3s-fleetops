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
      enable = false;
    };

    harbor = {
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
      enable = false;
    };

    marquez = {
      domain = "marquez.${base-domain}";
      enable = false;
    };

    minio = {
      api-domain = "api.minio.${tail-domain}";
      domain = "minio.${tail-domain}";
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
      enable = true;
      oauth = { inherit (secrets.tailscale) authKey clientId clientSecret; };
    };

    traefik.enable = true;
  };
}
