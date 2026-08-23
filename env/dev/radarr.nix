{ config, ... }:
{
  services.radarr = {
    databaseTarget = "postgresql";
    database.enable = true;

    enable = true;
    hostAffinity = "edgenix";
    image = "linuxserver/radarr:6.3.0.10514-ls313";

    ingressProvider = "traefik-lan";
    ingress.tls.enable = true;

    nfs = {
      enable = true;
      server = config.devDefaults.nasHost;
      path = "${config.devDefaults.nasBase}";
    };

    replicas = 1;
    storageClassName = "longhorn";
    vpn.enable = false;
  };
}
