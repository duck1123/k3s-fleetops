{ config, ... }:
{
  services.booklore = {
    enable = false;
    # hostAffinity = "edgenix";

    databaseTarget = "mariadb";

    gid = "0";

    ingressProvider = "traefik-lan";
    ingress.localIngress = {
      enable = true;
      domain = "booklore.${config.devDefaults.homeDomain}";
      clusterIssuer = config.devDefaults.clusterIssuer;
      tls.enable = true;
    };

    nfsTarget = "nas";
    nfsSubPath = "Books";
    nfs.enable = true;

    uid = "0";
  };
}
