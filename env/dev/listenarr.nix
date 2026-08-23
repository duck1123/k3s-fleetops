{ config, ... }:
{
  services.listenarr = {
    databaseTarget = "postgresql";
    database.enable = false;

    enable = true;

    ingressProvider = "traefik-lan";
    ingress.tls.enable = true;

    nfs = {
      enable = true;
      server = config.devDefaults.nasHost;
      path = "${config.devDefaults.nasBase}";

      audiobooks = {
        enable = true;
        path = "${config.devDefaults.nasBase}/Audiobooks";
      };
    };

    replicas = 1;
    storageClassName = "longhorn";

    vpn = {
      enable = false;
      sharedGluetunService = "gluetun.gluetun";
    };
  };
}
